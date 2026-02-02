import { useEffect, useMemo, useRef, useState } from "react";
import { io } from "socket.io-client";
import GlassPanel from "./components/ui/GlassPanel";
import GradientButton from "./components/ui/GradientButton";
import StatCard from "./components/ui/StatCard";
import OnboardingCarousel from "./components/ui/OnboardingCarousel";
import EmptyState, { RadarPulse, SuccessCheck } from "./components/ui/EmptyState";
import MessageBubble from "./components/ui/MessageBubble";
import { SkeletonCard, SkeletonLine } from "./components/ui/Skeleton";
import { useHaptics } from "./components/ui/useHaptics";

const API_BASE = import.meta.env.VITE_API_BASE_URL || window.location.origin;

const fetchJson = async (url, options = {}) => {
  const response = await fetch(url, options);
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data.error || "Request failed");
  }
  return data;
};

const formatLogMeta = (meta) => {
  if (!meta) return "";
  try {
    return JSON.stringify(meta);
  } catch {
    return String(meta);
  }
};

export default function App() {
  const [token, setToken] = useState("");
  const [credentials, setCredentials] = useState({ username: "", password: "" });
  const [stats, setStats] = useState({
    connectedUsers: 0,
    waitingUsers: 0,
    reports: 0,
    backendInstances: 1
  });
  const [reports, setReports] = useState([]);
  const [logs, setLogs] = useState([]);
  const [maintenance, setMaintenance] = useState({ enabled: false, message: "" });
  const [maintenanceMessage, setMaintenanceMessage] = useState("");
  const [error, setError] = useState("");
  const [hasLoaded, setHasLoaded] = useState(false);
  const [isCompactHeader, setIsCompactHeader] = useState(false);
  const socketRef = useRef(null);
  const { trigger } = useHaptics();

  const headers = useMemo(
    () => ({
      "Content-Type": "application/json",
      Authorization: token ? `Bearer ${token}` : ""
    }),
    [token]
  );

  const loadData = async () => {
    if (!token) return;
    try {
      const [statsRes, reportsRes, maintenanceRes] = await Promise.all([
        fetchJson(`${API_BASE}/api/admin/stats`, { headers }),
        fetchJson(`${API_BASE}/api/admin/reported`, { headers }),
        fetchJson(`${API_BASE}/api/maintenance`, { headers })
      ]);
      setStats(statsRes);
      setReports(reportsRes.reports || []);
      setMaintenance(maintenanceRes);
      setMaintenanceMessage(maintenanceRes.message || "");
      setHasLoaded(true);
    } catch (err) {
      setError(err.message);
    }
  };

  useEffect(() => {
    if (!token) return;
    loadData();
    const interval = setInterval(loadData, 5000);
    return () => clearInterval(interval);
  }, [token]);

  useEffect(() => {
    if (!token) return;
    const socket = io(`${API_BASE}/admin`, {
      auth: { token },
      transports: ["websocket", "polling"]
    });

    socket.on("connect_error", (err) => {
      setError(err.message || "Failed to connect to log stream");
    });

    socket.on("log:history", (entries) => {
      setLogs(entries || []);
    });

    socket.on("log:entry", (entry) => {
      setLogs((prev) => [...prev, entry].slice(-200));
    });

    socketRef.current = socket;
    return () => {
      socket.disconnect();
    };
  }, [token]);

  useEffect(() => {
    const handleScroll = () => {
      setIsCompactHeader(window.scrollY > 12);
    };
    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  const handleLogin = async (event) => {
    event.preventDefault();
    setError("");
    try {
      const data = await fetchJson(`${API_BASE}/api/admin/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(credentials)
      });
      setToken(data.token);
    } catch (err) {
      setError(err.message);
    }
  };

  const handleBan = async (userId) => {
    trigger();
    setError("");
    try {
      await fetchJson(`${API_BASE}/api/admin/ban`, {
        method: "POST",
        headers,
        body: JSON.stringify({ userId, reason: "Admin action" })
      });
      await loadData();
    } catch (err) {
      setError(err.message);
    }
  };

  const handleLogout = async () => {
    trigger();
    try {
      if (token) {
        await fetchJson(`${API_BASE}/api/admin/logout`, {
          method: "POST",
          headers
        });
      }
    } catch (err) {
      setError(err.message);
    } finally {
      socketRef.current?.disconnect();
      setToken("");
    }
  };

  const handleMaintenanceUpdate = async (enabled) => {
    setError("");
    try {
      const data = await fetchJson(`${API_BASE}/api/admin/maintenance`, {
        method: "POST",
        headers,
        body: JSON.stringify({
          enabled,
          message: maintenanceMessage
        })
      });
      setMaintenance(data);
      setMaintenanceMessage(data.message || "");
    } catch (err) {
      setError(err.message);
    }
  };

  if (!token) {
    return (
      <div className="min-h-screen grid gap-8 lg:grid-cols-[1.05fr_0.95fr] items-center p-6">
        <GlassPanel className="p-8 space-y-6">
          <div className="space-y-2">
            <p className="text-xs uppercase tracking-[0.4em] text-emerald-400">
              Anon Chat Admin
            </p>
            <h1 className="text-3xl font-semibold text-slate-50">
              Secure access to the live moderation suite.
            </h1>
            <p className="text-sm text-slate-400">
              Authenticate to monitor real-time connections, reports, and safety signals.
            </p>
          </div>
          {error && <p className="text-red-400 text-sm">{error}</p>}
          <form onSubmit={handleLogin} className="space-y-4">
            <div>
              <label className="text-xs uppercase tracking-[0.3em] text-slate-400">
                Username
              </label>
              <input
                className="mt-2 w-full rounded-2xl bg-slate-900/70 border border-slate-800 px-4 py-3 focus:outline-none focus:ring-2 focus:ring-emerald-400"
                value={credentials.username}
                onChange={(event) =>
                  setCredentials((prev) => ({ ...prev, username: event.target.value }))
                }
              />
            </div>
            <div>
              <label className="text-xs uppercase tracking-[0.3em] text-slate-400">
                Password
              </label>
              <input
                type="password"
                className="mt-2 w-full rounded-2xl bg-slate-900/70 border border-slate-800 px-4 py-3 focus:outline-none focus:ring-2 focus:ring-emerald-400"
                value={credentials.password}
                onChange={(event) =>
                  setCredentials((prev) => ({ ...prev, password: event.target.value }))
                }
              />
            </div>
            <GradientButton type="submit" className="w-full justify-center">
              Sign in
            </GradientButton>
          </form>
        </GlassPanel>
        <div className="space-y-6">
          <OnboardingCarousel />
          <GlassPanel className="p-6 space-y-4">
            <div className="flex items-center gap-4">
              <RadarPulse />
              <div>
                <p className="text-xs uppercase tracking-[0.3em] text-slate-400">
                  Searching
                </p>
                <p className="text-sm text-slate-300">
                  Pairing users in the anonymous queue.
                </p>
              </div>
            </div>
            <div className="flex items-center gap-4">
              <SuccessCheck />
              <div>
                <p className="text-xs uppercase tracking-[0.3em] text-slate-400">
                  Verified
                </p>
                <p className="text-sm text-slate-300">
                  Reports reviewed with instant action states.
                </p>
              </div>
            </div>
          </GlassPanel>
        </div>
      </div>
    );
  }

  const formattedLogs = logs.map((entry) => ({
    ...entry,
    meta: entry.meta ? formatLogMeta(entry.meta) : ""
  }));

  return (
    <div className="min-h-screen p-6 space-y-8">
      <div
        className={`compact-header sticky top-0 z-10 px-6 py-4 rounded-3xl bg-black/40 border border-slate-800/60 backdrop-blur-xl ${
          isCompactHeader ? "compact" : ""
        }`}
      >
        <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.4em] text-emerald-400">
              Control Center
            </p>
            <h1 className="text-2xl font-semibold">Anon Chat Admin</h1>
            <p className="text-slate-400">Live monitoring and premium safety controls.</p>
          </div>
          <button
            onClick={handleLogout}
            className="text-sm text-slate-300 hover:text-emerald-300 transition"
          >
            Log out
          </button>
        </div>
      </div>

      {error && <p className="text-red-400 text-sm">{error}</p>}

      <div className="grid gap-4 md:grid-cols-4">
        {hasLoaded ? (
          <>
            <StatCard label="Connected" value={stats.connectedUsers} hint="Live sessions">
              <SuccessCheck />
            </StatCard>
            <StatCard label="Queue" value={stats.waitingUsers} hint="Searching now">
              {stats.waitingUsers > 0 ? <RadarPulse /> : <SuccessCheck />}
            </StatCard>
            <StatCard label="Reports" value={stats.reports} hint="Escalations">
              {stats.reports === 0 ? <SuccessCheck /> : <RadarPulse />}
            </StatCard>
            <StatCard
              label="Backend Instances"
              value={stats.backendInstances}
              hint="Scaling monitor"
            >
              <SuccessCheck />
            </StatCard>
          </>
        ) : (
          <>
            <SkeletonCard />
            <SkeletonCard />
            <SkeletonCard />
            <SkeletonCard />
          </>
        )}
      </div>

      <div className="bg-slate-900 rounded-2xl p-6 mb-8">
        <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
          <div>
            <h2 className="text-lg font-semibold">Maintenance Mode</h2>
            <p className="text-sm text-slate-400">
              Toggle maintenance to gracefully inform mobile users of updates.
            </p>
          </div>
          <button
            onClick={() => handleMaintenanceUpdate(!maintenance.enabled)}
            className={`px-4 py-2 rounded-lg font-semibold ${
              maintenance.enabled
                ? "bg-amber-500 hover:bg-amber-400"
                : "bg-emerald-500 hover:bg-emerald-400"
            }`}
          >
            {maintenance.enabled ? "Disable Maintenance" : "Enable Maintenance"}
          </button>
        </div>
        <div className="mt-4">
          <label className="text-sm text-slate-300">Maintenance message</label>
          <textarea
            className="mt-2 w-full rounded-lg bg-slate-800 border-slate-700 min-h-[96px]"
            value={maintenanceMessage}
            onChange={(event) => setMaintenanceMessage(event.target.value)}
          />
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <GlassPanel className="p-6 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold">Reported Users</h2>
            <span className="text-xs uppercase tracking-[0.3em] text-slate-500">
              Moderation
            </span>
          </div>
          <div className="space-y-3">
            {!hasLoaded && (
              <div className="space-y-3">
                <SkeletonLine className="w-full" />
                <SkeletonLine className="w-4/5" />
              </div>
            )}
            {hasLoaded && reports.length === 0 && (
              <EmptyState
                title="No Reports"
                subtitle="Everything is calm in the queue."
              />
            )}
            {reports.map((report) => (
              <div
                key={report.id}
                className="glass-panel p-4 flex flex-col md:flex-row md:items-center md:justify-between gap-4 pop-in"
              >
                <div className="space-y-2">
                  <p className="text-sm text-slate-300">
                    Reported ID: <span className="font-semibold">{report.reported_id}</span>
                  </p>
                  <p className="text-xs text-slate-400">Reason: {report.reason}</p>
                  <p className="text-xs text-slate-500">
                    Reporter: {report.reporter_id} •{" "}
                    {new Date(report.created_at).toLocaleString()}
                  </p>
                  {report.image_url && (
                    <div className="mt-2">
                      <p className="text-xs text-slate-400">Reported image</p>
                      <a
                        href={report.image_url}
                        target="_blank"
                        rel="noreferrer"
                        className="inline-flex items-center gap-2 text-xs text-emerald-300 hover:text-emerald-200"
                      >
                        View full size
                      </a>
                      <img
                        src={report.image_url}
                        alt="Reported content"
                        className="mt-2 h-24 w-24 rounded-lg object-cover border border-slate-700"
                      />
                    </div>
                  )}
                </div>
                <button
                  onClick={() => handleBan(report.reported_id)}
                  className="px-4 py-2 rounded-full bg-red-500/80 hover:bg-red-500 text-sm font-semibold transition"
                >
                  Ban
                </button>
              </div>
            ))}
          </div>
        </GlassPanel>

        <GlassPanel className="p-6 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold">System Logs</h2>
            <span className="text-xs uppercase tracking-[0.3em] text-slate-500">
              Live Feed
            </span>
          </div>
          <div className="h-96 overflow-y-auto space-y-4 pr-2">
            {!hasLoaded && (
              <div className="space-y-3">
                <SkeletonLine className="w-full" />
                <SkeletonLine className="w-4/5" />
                <SkeletonLine className="w-3/5" />
              </div>
            )}
            {hasLoaded && formattedLogs.length === 0 && (
              <EmptyState title="Quiet" subtitle="No logs streaming right now." />
            )}
            {formattedLogs.map((entry) => (
              <div key={entry.id} className="pop-in">
                <MessageBubble entry={entry} />
              </div>
            ))}
          </div>
        </GlassPanel>
      </div>
    </div>
  );
}
