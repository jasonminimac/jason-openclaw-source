import type { OpenClawPluginApi } from "openclaw/plugin-sdk";
import { registerWebchatSubagentHooks } from "./src/subagent-hooks.js";

const plugin = {
  id: "webchat",
  name: "Webchat",
  description: "Webchat subagent thread-binding plugin — enables mode=session for webchat spawns",
  register(api: OpenClawPluginApi) {
    registerWebchatSubagentHooks(api);
  },
};

export default plugin;
