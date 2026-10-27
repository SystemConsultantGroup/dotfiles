import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Check, LoaderCircle, Monitor, Moon, Sun } from "lucide-react";
import { Button } from "@/components/ui/button";
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

function RegistrationRow({ device }: { device: Device }) {
  const [name, setName] = useState(device.dns?.name ?? "");
  const mutation = useSetting("/api/me/dns");
  return (
    <tr className="bg-muted/30">
      <td>
        <form
          id="registration-form"
          onSubmit={(event) => {
            event.preventDefault();
            mutation.mutate({ name });
          }}
        >
          <Label className="sr-only" htmlFor="dns-name">
            Your DNS name
          </Label>
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
              disabled={!device.editable || mutation.isPending}
              className="w-40 font-mono"
            />
            <span className="text-muted-foreground">.{device.domain}</span>
          </div>
        </form>
      </td>
      <td>
        <span className="font-mono">{device.ip}</span>
        <span className="ml-2 text-xs text-muted-foreground">You</span>
      </td>
      <td>
        <div className="space-y-2">
          <div className="flex gap-2">
            <Button
              type="submit"
              form="registration-form"
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
              Automatic
            </Button>
          </div>
          <Feedback error={mutation.error} saved={mutation.isSuccess} />
        </div>
      </td>
    </tr>
  );
}

function Records({ device }: { device: Device }) {
  const [search, setSearch] = useState("");
  const records = device.records.filter(
    (record) =>
      record.ip !== device.ip &&
      `${record.fqdn} ${record.ip}`
        .toLowerCase()
        .includes(search.trim().toLowerCase()),
  );
  return (
    <div className="space-y-4">
      <Label className="sr-only" htmlFor="record-search">
        Search DNS records
      </Label>
      <Input
        id="record-search"
        type="search"
        placeholder="Search by name or IP"
        value={search}
        onChange={(event) => setSearch(event.target.value)}
        className="sm:max-w-xs"
      />
      <div
        className="overflow-x-auto rounded-lg border"
        role="region"
        aria-label="DNS records"
        tabIndex={0}
      >
        <table className="data-table">
          <caption className="sr-only">
            Internal DNS records. Your editable registration is pinned first;
            search filters the other records.
          </caption>
          <thead>
            <tr>
              <th scope="col">DNS name</th>
              <th scope="col">IPv4 address</th>
              <th scope="col">Actions</th>
            </tr>
          </thead>
          <tbody>
            <RegistrationRow
              key={`${device.ip}:${device.dns?.name}:${device.dns?.custom}`}
              device={device}
            />
            {records.map((record) => (
              <tr key={record.ip}>
                <td className="font-mono">{record.fqdn}</td>
                <td className="font-mono">{record.ip}</td>
                <td>
                  <span className="sr-only">Read only</span>
                  <span aria-hidden="true" className="text-muted-foreground">
                    —
                  </span>
                </td>
              </tr>
            ))}
            {records.length === 0 && (
              <tr>
                <td colSpan={3} className="text-center text-muted-foreground">
                  {search ? "No matching records." : "No other records."}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function RouteRow({ device, route }: { device: Device; route: Route }) {
  const [selected, setSelected] = useState(route.selected);
  const mutation = useSetting("/api/me/routes");
  const upstream = device.upstreams.find((item) => item.id === selected);
  return (
    <tr>
      <th scope="row" className="font-medium">
        <Label htmlFor={`route-${route.id}`}>{route.label}</Label>
      </th>
      <td>
        <div className="min-w-44 space-y-2">
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
          {upstream?.health?.ready === false && (
            <p className="max-w-64 text-xs text-amber-700 dark:text-amber-400">
              Unavailable. Traffic will not fall back to another exit.
            </p>
          )}
        </div>
      </td>
      <td>
        <div className="space-y-2">
          <Button
            aria-label={`Apply ${route.label}`}
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
          <Feedback error={mutation.error} saved={mutation.isSuccess} />
        </div>
      </td>
    </tr>
  );
}

function Routes({ device }: { device: Device }) {
  return (
    <div className="space-y-3">
      <div
        className="overflow-x-auto rounded-lg border"
        role="region"
        aria-label="Internet exits"
        tabIndex={0}
      >
        <table className="data-table">
          <caption className="sr-only">
            Internet exit for each of your connection paths.
          </caption>
          <thead>
            <tr>
              <th scope="col">Connection</th>
              <th scope="col">Internet exit</th>
              <th scope="col">Actions</th>
            </tr>
          </thead>
          <tbody>
            {device.routes.map((route) => (
              <RouteRow
                key={`${device.ip}:${route.id}:${route.selected}`}
                device={device}
                route={route}
              />
            ))}
          </tbody>
        </table>
      </div>
      <p className="text-xs text-muted-foreground">
        Changes apply to new connections.
      </p>
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
    <div className="mx-auto min-h-screen max-w-5xl px-4 sm:px-6">
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
              <Records device={device} />
            ) : (
              <Routes device={device} />
            )}
          </>
        )}
      </main>
    </div>
  );
}
