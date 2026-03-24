import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { createServerClient } from '@supabase/auth-helpers-nextjs';
import { normalizeWeights, type ScoreWeights } from '@travel-af/domain/src/scoring';

export async function POST(req: Request) {
  const cookieStore = await cookies();

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string) {
          return cookieStore.get(name)?.value;
        },
      },
    }
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  let body: Partial<ScoreWeights>;

  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }

  const normalized = normalizeWeights(body ?? {});

  const { error } = await supabase
    .from('user_score_preferences')
    .upsert(
      {
        user_id: user.id,
        advisory: normalized.travelGov,
        seasonality: normalized.seasonality,
        visa: normalized.visa,
        affordability: normalized.affordability,
        language: normalized.language,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'user_id' }
    );

  if (error) {
    console.error('[score-weights] upsert failed', error);
    return NextResponse.json({ error: 'Failed to save weights' }, { status: 500 });
  }

  return NextResponse.json({ weights: normalized });
}
