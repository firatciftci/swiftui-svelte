import path from "node:path";
import process from "node:process";
import { syncRoutes } from "../src/routes.ts";

for (const source of ["example/src", "test/router/src"]) {
  syncRoutes(process.cwd(), path.resolve(source));
}
