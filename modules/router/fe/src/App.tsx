import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Check, LoaderCircle, Monitor, Moon, Sun } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { api, useSetting } from "@/lib/api";
import type { Device, Route } from "@/lib/api";

type Theme = "system" | "light" | "dark";

function ThemeControl() {
  const [theme, setTheme] = useState<Theme>(() => {
    try {
      const saved = localStorage.getItem("router-theme");
      if (saved === "light" || saved === "dark") return saved;
    } catch {
      /* Use the OS preference when storage is unavailable. */
    }
    return "system";
  });
  useEffect(() => {
    const media = matchMedia("(prefers-color-scheme: dark)");
    const apply = () => {
      const dark = theme === "dark" || (theme === "system" && media.matches);
      document.documentElement.classList.toggle("dark", dark);
      document.documentElement.style.colorScheme = dark ? "dark" : "light";
    };
    apply();
    media.addEventListener("change", apply);
    try {
      localStorage.setItem("router-theme", theme);
    } catch {
      /* Optional preference persistence. */
    }
    return () => media.removeEventListener("change", apply);
  }, [theme]);
  return (
    <div
      className="flex gap-1 rounded-lg border p-1"
      role="group"
      aria-label="Appearance"
    >
      {(
        [
          { value: "system", label: "System theme", icon: Monitor },
          { value: "light", label: "Light theme", icon: Sun },
          { value: "dark", label: "Dark theme", icon: Moon },
        ] as const
      ).map(({ value, label, icon: Icon }) => (
        <Button
          key={value}
          variant={theme === value ? "secondary" : "ghost"}
          size="icon"
          aria-label={label}
          aria-pressed={theme === value}
          title={label}
          onClick={() => setTheme(value)}
        >
          <Icon className="size-4" />
        </Button>
      ))}
    </div>
  );
}

function Feedback({ error, saved }: { error: Error | null; saved: boolean }) {
  return (
    <div className="text-sm" aria-live="polite">
      {error ? (
        <p className="text-destructive">{error.message}</p>
      ) : saved ? (
        <p className="flex items-center gap-1.5 text-emerald-700 dark:text-emerald-400">
          <Check className="size-4" />
          Saved
        </p>
      ) : null}
    </div>
  );
}

function Registration({ device }: { device: Device }) {
  const [name, setName] = useState(device.dns?.name ?? "");
  const mutation = useSetting("/api/me/dns");
  return (
    <Card>
      <CardHeader>
        <CardTitle>Your registration</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <p className="font-mono text-sm text-muted-foreground">{device.ip}</p>
        <form
          className="space-y-4"
          onSubmit={(event) => {
            event.preventDefault();
            mutation.mutate({ name });
          }}
        >
          <div className="space-y-2">
            <Label htmlFor="dns-name">DNS name</Label>
            <div className="flex flex-wrap items-center gap-2">
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
                disabled={!device.editable || mutation.isPending}
                className="min-w-0 flex-1 basis-40 font-mono"
                aria-describedby="dns-help"
              />
              <span className="text-sm text-muted-foreground">
                .{device.domain}
              </span>
            </div>
            <p id="dns-help" className="text-xs text-muted-foreground">
              Letters, numbers, and hyphens.
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            <Button
              type="submit"
              disabled={
                !device.editable ||
                mutation.isPending ||
                (name === device.dns?.name && device.dns.custom)
              }
            >
              {mutation.isPending && (
                <LoaderCircle className="size-4 animate-spin" />
              )}
              Save
            </Button>
            <Button
              type="button"
              variant="outline"
              disabled={
                !device.editable || mutation.isPending || !device.dns?.custom
              }
              onClick={() => mutation.mutate({ name: null })}
            >
              Use automatic name
            </Button>
          </div>
        </form>
        <Feedback error={mutation.error} saved={mutation.isSuccess} />
      </CardContent>
    </Card>
  );
}

function Records({ device }: { device: Device }) {
  const [search, setSearch] = useState("");
  const records = device.records.filter((record) =>
    `${record.fqdn} ${record.ip}`
      .toLowerCase()
      .includes(search.trim().toLowerCase()),
  );
  return (
    <Card>
      <CardHeader>
        <CardTitle>DNS records</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <Label className="sr-only" htmlFor="record-search">
          Search DNS records
        </Label>
        <Input
          id="record-search"
          type="search"
          placeholder="Search by name or IP"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <caption className="sr-only">
              All internal IPv4 DNS records. Only your own registration is
              editable.
            </caption>
            <thead>
              <tr className="border-b text-muted-foreground">
                <th scope="col" className="pb-3 pr-4 font-medium">
                  Name
                </th>
                <th scope="col" className="pb-3 font-medium">
                  IPv4 address
                </th>
              </tr>
            </thead>
            <tbody>
              {records.map((record) => (
                <tr key={record.ip} className="border-b last:border-0">
                  <td className="py-3 pr-4">
                    <span className="break-all font-mono text-xs sm:text-sm">
                      {record.fqdn}
                    </span>
                    {record.ip === device.ip && (
                      <span className="ml-2 text-xs text-muted-foreground">
                        You
                      </span>
                    )}
                  </td>
                  <td className="py-3 font-mono text-xs sm:text-sm">
                    {record.ip}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {records.length === 0 && (
          <p className="py-4 text-center text-sm text-muted-foreground">
            {search ? "No matching records." : "No records yet."}
          </p>
        )}
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
      <Label htmlFor={`route-${route.id}`}>{route.label}</Label>
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
          {mutation.isPending && (
            <LoaderCircle className="size-4 animate-spin" />
          )}
          Apply
        </Button>
      </div>
      {upstream?.health?.ready === false && (
        <p className="text-sm text-amber-700 dark:text-amber-400">
          This exit is unavailable. Traffic will not fall back to another exit.
        </p>
      )}
      <Feedback error={mutation.error} saved={mutation.isSuccess} />
    </div>
  );
}

export default function App() {
  const [page, setPage] = useState(() =>
    location.hash === "#/routes" ? "routes" : "registration",
  );
  useEffect(() => {
    const navigate = () =>
      setPage(location.hash === "#/routes" ? "routes" : "registration");
    addEventListener("hashchange", navigate);
    return () => removeEventListener("hashchange", navigate);
  }, []);
  useEffect(() => {
    document.title = `${page === "routes" ? "Routes" : "Registration / DDNS"} · SCG Router`;
  }, [page]);
  const query = useQuery({
    queryKey: ["me"],
    queryFn: () => api(),
    refetchInterval: 30_000,
  });
  const device = query.data;
  return (
    <div className="mx-auto min-h-screen max-w-3xl px-4 sm:px-6">
      <header className="flex items-center justify-between gap-4 py-5">
        <span className="text-lg font-semibold tracking-tight">SCG Router</span>
        <ThemeControl />
      </header>
      <nav className="mb-8 flex gap-6 border-b" aria-label="Main navigation">
        {[
          {
            id: "registration",
            label: "Registration / DDNS",
            href: "#/registration",
          },
          { id: "routes", label: "Routes", href: "#/routes" },
        ].map((item) => (
          <a
            key={item.id}
            href={item.href}
            aria-current={page === item.id ? "page" : undefined}
            className={`border-b-2 px-1 py-3 text-sm font-medium transition-colors ${page === item.id ? "border-foreground text-foreground" : "border-transparent text-muted-foreground hover:text-foreground"}`}
          >
            {item.label}
          </a>
        ))}
      </nav>
      <main className="space-y-5 pb-12">
        <h1 className="text-2xl font-semibold tracking-tight">
          {page === "routes" ? "Routes" : "Registration / DDNS"}
        </h1>
        {query.isPending && (
          <p
            className="flex items-center gap-2 text-sm text-muted-foreground"
            role="status"
          >
            <LoaderCircle className="size-4 animate-spin" />
            Loading…
          </p>
        )}
        {query.isError && (
          <div role="alert" className="space-y-3 rounded-lg border p-4">
            <p className="text-sm text-destructive">{query.error.message}</p>
            <Button
              variant="outline"
              onClick={() => void query.refetch()}
              disabled={query.isFetching}
            >
              Retry
            </Button>
          </div>
        )}
        {device && (
          <>
            {!device.editable && (
              <p role="alert" className="text-sm text-destructive">
                {device.edit_error ?? "This address cannot change settings."}
              </p>
            )}
            {!device.applied && (
              <p
                role="alert"
                className="text-sm text-amber-700 dark:text-amber-400"
              >
                Changes could not be applied. The previous configuration is
                still active.
              </p>
            )}
            {page === "registration" ? (
              <>
                <Registration
                  key={`${device.ip}:${device.dns?.name}:${device.dns?.custom}`}
                  device={device}
                />
                <Records device={device} />
              </>
            ) : (
              <Card>
                <CardHeader>
                  <CardTitle>Internet exits</CardTitle>
                </CardHeader>
                <CardContent className="space-y-6">
                  {device.routes.map((route) => (
                    <RouteSetting
                      key={`${device.ip}:${route.id}:${route.selected}`}
                      device={device}
                      route={route}
                    />
                  ))}
                  <p className="text-xs text-muted-foreground">
                    Changes apply to new connections.
                  </p>
                </CardContent>
              </Card>
            )}
          </>
        )}
      </main>
    </div>
  );
}
