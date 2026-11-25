#!/usr/bin/env node
import process from "node:process";
import { run } from "swiftui-svelte/create";

run(process.argv.slice(2));
