import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import {
  ArrowRight,
  Check,
  CircleAlert,
  Globe2,
  LoaderCircle,
  Network,
  RefreshCw,
  ShieldCheck,
} from "lucide-react";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Separator } from "@/components/ui/separator";
import { api, useSetting } from "@/lib/api";
import type { Device, Route } from "@/lib/api";

function Feedback({ error, saved }: { error: Error | null; saved: boolean }) {
  return (
    <div className="min-h-5 text-sm" aria-live="polite">
      {error ? (
        <p className="text-destructive">{error.message}</p>
      ) : saved ? (
        <p className="flex items-center gap-1.5 text-emerald-700">
          <Check className="size-4" /> Saved
        </p>
      ) : null}
    </div>
  );
}

function Dns({ device }: { device: Device }) {
  const [name, setName] = useState(device.dns?.name ?? "");
  const mutation = useSetting("/api/me/dns");
  const pending = mutation.isPending;
  return (
    <Card>
      <CardHeader>
        <div className="mb-3 flex size-10 items-center justify-center rounded-xl bg-blue-50 text-blue-700">
          <Globe2 className="size-5" />
        </div>
        <CardTitle>Internal DNS</CardTitle>
        <CardDescription>
          A name for this address, reachable from the office and WARP through
          router DNS.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-5">
        <div className="rounded-lg border bg-muted/40 px-4 py-3">
          <p className="mb-1 text-xs font-medium uppercase tracking-wider text-muted-foreground">
            Current A record
          </p>
          <p className="break-all font-mono text-sm">
            {device.dns?.fqdn ?? "Not registered"}
          </p>
          <p className="mt-1 text-xs text-muted-foreground">
            {device.dns?.custom ? "Custom name" : "Automatic name"} ·{" "}
            {device.ip}
          </p>
        </div>
        <form
          className="space-y-3"
          onSubmit={(event) => {
            event.preventDefault();
            mutation.mutate({ name });
          }}
        >
          <Label htmlFor="dns-name">Device name</Label>
          <div className="flex items-center gap-2">
            <Input
              id="dns-name"
              value={name}
              onChange={(event) => {
                setName(event.target.value.toLowerCase());
                mutation.reset();
              }}
              required
              maxLength={63}
              pattern="[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?"
              autoComplete="off"
              spellCheck={false}
              disabled={!device.editable || pending}
              className="min-w-0 font-mono"
              aria-describedby="dns-help"
            />
            <span className="shrink-0 text-sm text-muted-foreground">
              .{device.domain}
            </span>
          </div>
          <p
            id="dns-help"
            className="text-xs leading-relaxed text-muted-foreground"
          >
            Lowercase letters, numbers, and hyphens. Names are unique.
            DHCP-reported names are used automatically when available.
          </p>
          <div className="flex flex-wrap gap-2 pt-1">
            <Button
              type="submit"
              disabled={
                !device.editable ||
                pending ||
                (name === device.dns?.name && device.dns.custom)
              }
            >
              {pending && <LoaderCircle className="size-4 animate-spin" />}Save
              name
            </Button>
            <Button
              type="button"
              variant="outline"
              disabled={!device.editable || pending || !device.dns?.custom}
              onClick={() => mutation.mutate({ name: null })}
            >
              Use automatic
            </Button>
          </div>
        </form>
        <Feedback error={mutation.error} saved={mutation.isSuccess} />
      </CardContent>
    </Card>
  );
}

function RouteSetting({ device, route }: { device: Device; route: Route }) {
  const [selected, setSelected] = useState(route.selected);
  const mutation = useSetting("/api/me/routes");
  const upstream = device.upstreams.find((item) => item.id === selected);
  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between gap-3">
        <Label htmlFor={`route-${route.id}`}>{route.label}</Label>
        <span className="text-xs text-muted-foreground">
          Default:{" "}
          {device.upstreams.find((item) => item.id === route.default)?.label ??
            route.default}
        </span>
      </div>
      <div className="flex gap-2">
        <Select
          value={selected}
          onValueChange={(value) => {
            setSelected(value);
            mutation.reset();
          }}
          disabled={!device.editable || mutation.isPending}
        >
          <SelectTrigger id={`route-${route.id}`} className="w-full">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {device.upstreams.map((item) => (
              <SelectItem key={item.id} value={item.id}>
                {item.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Button
          disabled={
            !device.editable ||
            mutation.isPending ||
            selected === route.selected
          }
          onClick={() =>
            mutation.mutate({ ingress: route.id, upstream: selected })
          }
        >
          {mutation.isPending ? (
            <LoaderCircle className="size-4 animate-spin" />
          ) : (
            <ArrowRight className="size-4" />
          )}
          <span className="sr-only">Apply {route.label}</span>
        </Button>
      </div>
      <p
        className={`flex items-center gap-1.5 text-xs ${upstream?.health?.ready ? "text-emerald-700" : "text-amber-700"}`}
      >
        <span
          className={`size-1.5 shrink-0 rounded-full ${upstream?.health?.ready ? "bg-emerald-600" : "bg-amber-500"}`}
        />
        {upstream?.health?.detail ?? "Availability not yet known"}
      </p>
      <Feedback error={mutation.error} saved={mutation.isSuccess} />
    </div>
  );
}

function Routes({ device }: { device: Device }) {
  return (
    <Card>
      <CardHeader>
        <div className="mb-3 flex size-10 items-center justify-center rounded-xl bg-violet-50 text-violet-700">
          <Network className="size-5" />
        </div>
        <CardTitle>Internet exits</CardTitle>
        <CardDescription>
          Choose where traffic leaves the router for each of your connection
          paths.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-5">
        {device.routes.map((route, index) => (
          <div key={`${route.id}:${route.selected}`}>
            {index > 0 && <Separator className="mb-5" />}
            <RouteSetting device={device} route={route} />
          </div>
        ))}
        <div className="flex gap-2.5 rounded-lg bg-muted/50 p-3 text-xs leading-relaxed text-muted-foreground">
          <ShieldCheck className="mt-0.5 size-4 shrink-0" />
          <p>
            Fail closed: unavailable exits never fall back to another upstream.
            Changes affect new connections. Office and Mesh destinations stay
            internal. Availability reflects the local link and route, not an
            end-to-end connectivity probe.
          </p>
        </div>
        {device.kind === "mesh" && (
          <p className="text-xs leading-relaxed text-muted-foreground">
            These settings affect traffic Cloudflare delivers to the router.
            Cloudflare routing decides whether traffic uses the base Mesh path
            or mesh-yt.
          </p>
        )}
      </CardContent>
    </Card>
  );
}

export default function App() {
  const query = useQuery({
    queryKey: ["me"],
    queryFn: () => api(),
    refetchInterval: 10_000,
    retry: 1,
  });
  const device = query.data;
  return (
    <div className="min-h-screen bg-stone-50/70">
      <header className="border-b bg-white">
        <div className="mx-auto flex max-w-5xl items-center justify-between gap-4 px-5 py-4 sm:px-8">
          <div className="flex items-center gap-3">
            <div className="flex size-9 items-center justify-center rounded-xl bg-zinc-900 text-white">
              <Network className="size-5" />
            </div>
            <span className="font-semibold tracking-tight">
              SCG{" "}
              <span className="font-normal text-muted-foreground">
                / router
              </span>
            </span>
          </div>
          <Badge variant="outline" className="gap-1.5">
            <ShieldCheck className="size-3.5" />
            IPv4 self-service
          </Badge>
        </div>
      </header>
      <main className="mx-auto max-w-5xl space-y-7 px-5 py-10 sm:px-8 sm:py-14">
        <section className="flex flex-wrap items-end justify-between gap-4">
          <div>
            <p className="mb-2 text-xs font-medium uppercase tracking-[0.18em] text-muted-foreground">
              Your device
            </p>
            <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">
              Your connection.
            </h1>
            <p className="mt-3 max-w-xl text-sm leading-relaxed text-muted-foreground">
              Manage the name and Internet exits for your current source
              address. No account or sign-in required.
            </p>
          </div>
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              void query.refetch();
            }}
            disabled={query.isFetching}
          >
            <RefreshCw
              className={`size-3.5 ${query.isFetching ? "animate-spin" : ""}`}
            />
            Refresh
          </Button>
        </section>
        {query.error && (
          <Alert variant="destructive">
            <CircleAlert />
            <AlertTitle>Unable to refresh your connection</AlertTitle>
            <AlertDescription>{query.error.message}</AlertDescription>
          </Alert>
        )}
        {!device && query.isPending && (
          <div
            className="flex items-center gap-3 py-16 text-sm text-muted-foreground"
            role="status"
          >
            <LoaderCircle className="size-5 animate-spin" />
            Loading your connection…
          </div>
        )}
        {device && (
          <>
            <div className="flex flex-wrap items-center gap-3 rounded-xl border bg-white px-5 py-4">
              <span className="font-mono text-base font-medium">
                {device.ip}
              </span>
              <Badge variant="secondary">
                {device.kind === "office" ? "Office LAN" : "WARP Mesh"}
              </Badge>
              {device.reported_name && (
                <span className="text-sm text-muted-foreground">
                  {device.reported_name}
                </span>
              )}
              <span
                className={`ml-auto flex items-center gap-1.5 text-xs ${device.applied ? "text-emerald-700" : "text-amber-700"}`}
              >
                {device.applied ? (
                  <Check className="size-3.5" />
                ) : (
                  <LoaderCircle className="size-3.5 animate-spin" />
                )}
                {device.applied ? "Policy applied" : "Changes pending"}
              </span>
            </div>
            {(!device.editable ||
              device.inventory_warning ||
              !device.applied) && (
              <Alert>
                <CircleAlert />
                <AlertTitle>
                  {!device.editable
                    ? "Settings are read-only"
                    : !device.applied
                      ? "Waiting for reconciliation"
                      : "Inventory temporarily unavailable"}
                </AlertTitle>
                <AlertDescription>
                  {device.edit_error ??
                    device.inventory_warning ??
                    "Saved changes will be retried automatically. The last applied policy remains in effect."}
                </AlertDescription>
              </Alert>
            )}
            <div className="grid items-start gap-5 md:grid-cols-2">
              <Dns
                key={`${device.ip}:${device.dns?.name}:${device.dns?.custom}`}
                device={device}
              />
              <Routes key={device.ip} device={device} />
            </div>
            <p className="text-xs leading-relaxed text-muted-foreground">
              Settings belong to this IPv4 address. Known DHCP and Mesh
              assignments are cleared when inventory confirms they have ended;
              untracked static addresses retain their settings. Connecting
              through another address gives you a separate identity.
              {device.expires
                ? ` Current DHCP lease expires ${new Date(device.expires * 1000).toLocaleString()}.`
                : ""}
            </p>
          </>
        )}
      </main>
    </div>
  );
}
