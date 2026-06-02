declare module '*.xcstrings' {
  const value: {
    strings?: Record<
      string,
      {
        localizations?: Record<
          string,
          {
            stringUnit?: {
              value?: string;
            };
          }
        >;
      }
    >;
  };

  export default value;
}
