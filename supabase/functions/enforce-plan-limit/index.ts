import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const PLAN_LIMITS: Record<string, { teams: number | null; matches: number | null }> = {
  free: { teams: 1, matches: 2 },
  pro: { teams: 1, matches: null },
  plus: { teams: 3, matches: null },
}

serve(async (req) => {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return json({ error: 'Unauthorized' }, 401)

  const { resource, teamId } = (await req.json()) as {
    resource: 'team' | 'match'
    teamId?: string
  }

  // Resolve the calling user from their JWT
  const userClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  )
  const { data: { user } } = await userClient.auth.getUser()
  if (!user) return json({ error: 'Unauthorized' }, 401)

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const { data: profile } = await admin
    .from('profiles')
    .select('plan, role')
    .eq('id', user.id)
    .single()

  // Admins bypass all limits
  if (!profile || profile.role === 'admin') {
    return json({ allowed: true }, 200)
  }

  const limits = PLAN_LIMITS[profile.plan as string] ?? PLAN_LIMITS.free

  if (resource === 'team') {
    const { count } = await admin
      .from('teams')
      .select('*', { count: 'exact', head: true })
      .eq('owner_id', user.id)

    if (limits.teams !== null && (count ?? 0) >= limits.teams) {
      return json(
        { error: 'plan_limit_exceeded', resource: 'team', limit: limits.teams, plan: profile.plan },
        403,
      )
    }
  }

  if (resource === 'match' && teamId) {
    if (limits.matches !== null) {
      const { count } = await admin
        .from('matches')
        .select('*', { count: 'exact', head: true })
        .eq('team_id', teamId)

      if ((count ?? 0) >= limits.matches) {
        return json(
          { error: 'plan_limit_exceeded', resource: 'match', limit: limits.matches, plan: profile.plan },
          403,
        )
      }
    }
  }

  return json({ allowed: true }, 200)
})

function json(data: unknown, status: number) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
