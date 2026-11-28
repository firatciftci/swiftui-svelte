#!/usr/bin/env node
import process from "node:process";
import { run } from "../dist/create.js";

await run(process.argv.slice(2));
