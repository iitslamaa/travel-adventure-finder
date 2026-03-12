// apps/web/lib/display/SoloFemaleSection.tsx
type Props = { raw?: number };

function headline(raw?: number) {
  if (typeof raw !== 'number') return 'Solo Female Travelers';
  if (raw >= 85) return 'Very positive safety picture';
  if (raw >= 70) return 'Generally positive picture';
  if (raw >= 55) return 'Mixed but manageable with precautions';
  return 'Notable concerns — plan carefully';
}

function summary(raw?: number) {
  if (typeof raw !== 'number') {
    return 'We’re missing enough community reports for this destination; treated as neutral.';
  }
  if (raw >= 85) {
    return 'Reports are very positive overall. Standard city awareness is enough in most areas.';
  }
  if (raw >= 70) {
    return 'Generally comfortable with routine precautions. Petty theft in busy zones is the main risk.';
  }
  if (raw >= 55) {
    return 'Experiences are mixed. Prefer well-lit routes at night and use trusted transport options.';
  }
  return 'Multiple reports of harassment or safety incidents. Research neighborhoods carefully and avoid late-night solo travel.';
}

export function SoloFemaleSection({ raw }: Props) {
  return (
    <>
      {/* headline lives under the section header, like Visa/Advisory */}
      <div className="mt-2 flex items-center gap-2">
        {/* the pill is already rendered in the table; keep this area text-only */}
        <span className="text-sm font-semibold">👩‍🧳 {headline(raw)}</span>
      </div>
      <p className="mt-2 text-sm leading-6">
        {summary(raw)}
      </p>
    </>
  );
}
