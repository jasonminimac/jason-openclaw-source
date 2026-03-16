/**
 * Webchat subagent thread-binding plugin.
 *
 * Enables `mode="session"` + `thread=true` for subagents spawned from
 * webchat sessions. Since webchat has no actual thread UI, the "thread"
 * is simply the parent webchat session — completion messages route back
 * to the same session that spawned the agent.
 *
 * Implements three hooks:
 *   subagent_spawning       — approves the thread bind, records the binding
 *   subagent_delivery_target — routes completions back to the requester session
 *   subagent_ended          — cleans up the binding
 */

import type { OpenClawPluginApi } from "openclaw/plugin-sdk";

// In-memory registry: childSessionKey → requester origin
const bindings = new Map<
  string,
  {
    channel: string;
    accountId?: string;
    to?: string;
    threadId?: string | number;
    requesterSessionKey: string;
  }
>();

export function registerWebchatSubagentHooks(api: OpenClawPluginApi) {
  api.on("subagent_spawning", (event) => {
    if (!event.threadRequested) {
      return;
    }

    const channel = event.requester?.channel?.trim().toLowerCase();
    if (channel !== "webchat") {
      // Let other channel plugins handle their own channels
      return;
    }

    // Record the binding — child session maps back to requester origin
    bindings.set(event.childSessionKey, {
      channel: "webchat",
      accountId: event.requester?.accountId,
      to: event.requester?.to,
      threadId: event.requester?.threadId,
      requesterSessionKey: "", // filled in via subagent_spawned ctx
    });

    api.logger.info(
      `[webchat] thread binding registered for ${event.childSessionKey} (label: ${event.label ?? "none"})`,
    );

    return { status: "ok" as const, threadBindingReady: true };
  });

  api.on("subagent_spawned", (event, ctx) => {
    // Backfill requesterSessionKey now that we have ctx
    const binding = bindings.get(event.childSessionKey);
    if (binding) {
      binding.requesterSessionKey = ctx.requesterSessionKey;
    }
  });

  api.on("subagent_delivery_target", (event) => {
    if (!event.expectsCompletionMessage) {
      return;
    }

    const requesterChannel = event.requesterOrigin?.channel?.trim().toLowerCase();
    if (requesterChannel !== "webchat") {
      return;
    }

    const binding = bindings.get(event.childSessionKey);
    if (!binding) {
      return;
    }

    // Route completion back to the webchat session that spawned the agent
    return {
      origin: {
        channel: "webchat",
        accountId: binding.accountId,
        to: binding.to,
        threadId: binding.threadId,
      },
    };
  });

  api.on("subagent_ended", (event) => {
    if (bindings.has(event.targetSessionKey)) {
      bindings.delete(event.targetSessionKey);
      api.logger.info(`[webchat] thread binding cleaned up for ${event.targetSessionKey}`);
    }
  });
}
