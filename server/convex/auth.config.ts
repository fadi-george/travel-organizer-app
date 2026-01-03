export default {
  providers: [
    {
      // Clerk issuer URL from the Clerk Dashboard
      // Format: https://verb-noun-00.clerk.accounts.dev (development)
      // or https://clerk.yourdomain.com (production)
      domain: process.env.CLERK_ISSUER_URL,
      applicationID: "convex",
    },
  ],
};
