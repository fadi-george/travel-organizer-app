import { defineApp } from "convex/server";
import migrations from "@convex-dev/migrations/convex.config";
import actionCache from "@convex-dev/action-cache/convex.config";

const app = defineApp();
app.use(migrations);
app.use(actionCache);

export default app;
