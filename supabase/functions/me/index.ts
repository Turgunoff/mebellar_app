import { createClient } from 'jsr:@supabase/supabase-js@2'

Deno.serve(async (req: Request) => {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return json({ error: 'Missing Authorization header' }, 401)
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  )

  const { data: { user }, error: authError } = await supabase.auth.getUser()
  if (authError || !user) {
    return json({ error: 'Unauthorized' }, 401)
  }

  const { data: profile, error } = await supabase
    .from('profiles')
    .select('full_name, phone, preferred_language')
    .eq('id', user.id)
    .single()

  if (error) {
    return json({ error: error.message }, 500)
  }

  return json({
    data: {
      id: user.id,
      email: user.email ?? '',
      full_name: profile.full_name,
      phone: profile.phone,
      preferred_language: profile.preferred_language ?? 'uz',
      seller_profile: null,
    },
  })
})

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
