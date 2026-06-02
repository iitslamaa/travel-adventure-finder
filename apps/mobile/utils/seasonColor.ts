export function getScoreColor(score: number) {
  if (score >= 85) {
    return {
      background: "rgba(86, 131, 93, 0.14)",
      text: "#436347",
      border: "rgba(86, 131, 93, 0.35)",
    };
  }

  if (score >= 70) {
    return {
      background: "rgba(211, 177, 104, 0.18)",
      text: "#805B2F",
      border: "rgba(211, 177, 104, 0.38)",
    };
  }

  return {
    background: "rgba(184, 112, 95, 0.16)",
    text: "#7C4B43",
    border: "rgba(184, 112, 95, 0.36)",
  };
}
