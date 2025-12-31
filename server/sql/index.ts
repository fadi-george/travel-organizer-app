import { Hono } from "hono";
import trips from "./routes/trips";
import destinations from "./routes/destinations";
import accommodations from "./routes/accommodations";
import flights from "./routes/flights";
import activities from "./routes/activities";

const app = new Hono();

// Mount route modules
app.route("/api/trips", trips);
app.route("/api", destinations);
app.route("/api", accommodations);
app.route("/api", flights);
app.route("/api", activities);

// Start server
const port = Number(process.env.PORT) || 3000;

export default {
  port,
  fetch: app.fetch,
};

console.log(`Server running on http://localhost:${port}`);
