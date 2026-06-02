export function firstArrayValue(value: unknown) {
  if (Array.isArray(value)) {
    const first = value[0];
    return typeof first === 'string' ? first.trim() || null : null;
  }

  return typeof value === 'string' ? value.trim() || null : null;
}

export function travelModeLabel(value: unknown) {
  switch (firstArrayValue(value)) {
    case 'solo':
      return 'Solo';
    case 'group':
      return 'Group';
    case 'both':
      return 'Solo + Group';
    default:
      return null;
  }
}

export function travelStyleLabel(value: unknown) {
  switch (firstArrayValue(value)) {
    case 'budget':
      return 'Budget';
    case 'comfortable':
      return 'Comfortable';
    case 'inBetween':
    case 'in_between':
      return 'In between';
    case 'both':
      return 'Both';
    default:
      return null;
  }
}
