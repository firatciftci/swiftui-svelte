import "./host.ts";
import { mountApp } from "#renderer";
import App from "./App.svelte";
import Bench from "./Bench.svelte";

mountApp(import.meta.env.MODE === "bench" ? Bench : App);
