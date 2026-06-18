import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14?target=deno'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  httpClient: Stripe.createFetchHttpClient(),
})

const PRICE_IDS: Record<string, string> = {
  pro: Deno.env.get('STRIPE_PRICE_PRO') ?? '',
  plus: Deno.env.get('STRIPE_PRICE_PLUS') ?? '',
}

serve(async (req) => {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return json({ error: 'Unauthorized' }, 401)

  const { plan } = (await req.json()) as { plan: 'pro' | 'plus' }
  const priceId = PRICE_IDS[plan]
  if (!priceId) return json({ error: 'Invalid plan' }, 400)

  const userClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  )
  const { data: { user } } = await userClient.auth.getUser()
  if (!user) return json({ error: 'Unauthorized' }, 401)

  const appUrl = Deno.env.get('APP_URL') ?? 'https://teamtrack.app'

  const session = await stripe.checkout.sessions.create({
    mode: 'subscription',
    line_items: [{ price: priceId, quantity: 1 }],
    customer_email: user.email,
    metadata: { user_id: user.id, plan },
    success_url: `${appUrl}/subscription?success=true`,
    cancel_url: `${appUrl}/subscription?canceled=true`,
  })

  return json({ url: session.url }, 200)
})

function json(data: unknown, status: number) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
