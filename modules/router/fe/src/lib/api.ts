import { useMutation, useQueryClient } from "@tanstack/react-query";

export type Upstream = {
  id: string;
  label: string;
  health: { ready: boolean; detail: string } | null;
};
export type Route = {
  id: string;
  label: string;
  selected: string;
  default: string;
};
export type Activity = {
  status: "online" | "offline" | "unknown";
  warning: string | null;
  last_activity: number | null;
  session_started_at: number | null;
  idle_seconds: number;
  retention_days: number;
  sampled_at: number;
  totals: { day: number; week: number };
  sessions: {
    started_at: number;
    last_activity: number;
    ended_at: number | null;
    end_reason: "inactivity" | "monitoring_gap" | null;
  }[];
};
export type Device = {
  id: string;
  identifier: string;
  activity: Activity | null;
  ip: string;
  kind: "office" | "mesh";
  domain: string;
  reported_name: string | null;
  expires: number | null;
  dns: { name: string; fqdn: string; custom: boolean } | null;
  records: { fqdn: string; ip: string }[];
  routes: Route[];
  upstreams: Upstream[];
  editable: boolean;
  edit_error: string | null;
  inventory_warning: string | null;
  applied: boolean;
};

export async function api(path = "/api/me", body?: unknown): Promise<Device> {
  const response = await fetch(path, {
    method: body === undefined ? "GET" : "PATCH",
    credentials: "omit",
    cache: "no-store",
    headers: body === undefined ? {} : { "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(30_000),
  });
  const data = await response.json().catch(() => null);
  if (!response.ok)
    throw new Error(data?.error ?? `Request failed (${response.status})`);
  return data as Device;
}

export function useSetting(path: string) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (body: unknown) => api(path, body),
    onSuccess: (device) => client.setQueryData(["me"], device),
  });
}
