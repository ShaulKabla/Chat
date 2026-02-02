import { useEffect, useMemo, useRef, useState } from "react";
import { io } from "socket.io-client";

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
  const [stats, setStats] = useState({ connectedUsers: 0, waitingUsers: 0, reports: 0 });
  const [reports, setReports] = useState([]);
  const [logs, setLogs] = useState([]);
  const [error, setError] = useState("");
  const socketRef = useRef(null);

  const headers = useMemo(
    () => ({
      "Content-Type": "application/json",
      Authorization: token ? `Bearer ${token}` : ""
    }),
    [token]
  );

  const loadData = async () => {
    if (!token) return;
    const [statsRes, reportsRes] = await Promise.all([
      fetchJson(`${API_BASE}/api/admin/stats`, { headers }),
      fetchJson(`${API_BASE}/api/admin/reported`, { headers })
    ]);
    setStats(statsRes);
    setReports(reportsRes.reports || []);
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

  if (!token) {
    return (
      <div className="min-h-screen flex items-center justify-center p-6">
        <form
          onSubmit={handleLogin}
          className="bg-slate-900 p-8 rounded-2xl shadow-xl w-full max-w-sm space-y-4"
        >
          <h1 className="text-xl font-semibold">Admin Login</h1>
          {error && <p className="text-red-400 text-sm">{error}</p>}
          <div>
            <label className="text-sm">Username</label>
            <input
              className="mt-1 w-full rounded-lg bg-slate-800 border-slate-700"
              value={credentials.username}
              onChange={(event) =>
                setCredentials((prev) => ({ ...prev, username: event.target.value }))
              }
            />
          </div>
          <div>
            <label className="text-sm">Password</label>
            <input
              type="password"
              className="mt-1 w-full rounded-lg bg-slate-800 border-slate-700"
              value={credentials.password}
              onChange={(event) =>
                setCredentials((prev) => ({ ...prev, password: event.target.value }))
              }
            />
          </div>
          <button
            type="submit"
            className="w-full bg-indigo-500 hover:bg-indigo-400 transition px-4 py-2 rounded-lg font-semibold"
          >
            Sign in
          </button>
        </form>
      </div>
    );
  }

  return (
    <div className="min-h-screen p-6">
      <div className="flex flex-col md:flex-row md:items-center md:justify-between mb-6 gap-4">
        <div>
          <h1 className="text-2xl font-semibold">Anon Chat Admin</h1>
          <p className="text-slate-400">Live monitoring and moderation.</p>
        </div>
        <button
          onClick={handleLogout}
          className="text-sm text-slate-300 hover:text-white"
        >
          Log out
        </button>
      </div>

      {error && <p className="text-red-400 text-sm mb-4">{error}</p>}

      <div className="grid gap-4 md:grid-cols-3 mb-8">
        <div className="bg-slate-900 rounded-2xl p-5">
          <p className="text-slate-400 text-sm">Connected Users</p>
          <p className="text-3xl font-semibold">{stats.connectedUsers}</p>
        </div>
        <div className="bg-slate-900 rounded-2xl p-5">
          <p className="text-slate-400 text-sm">Waiting Users</p>
          <p className="text-3xl font-semibold">{stats.waitingUsers}</p>
        </div>
        <div className="bg-slate-900 rounded-2xl p-5">
          <p className="text-slate-400 text-sm">Reports</p>
          <p className="text-3xl font-semibold">{stats.reports}</p>
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <div className="bg-slate-900 rounded-2xl p-6">
          <h2 className="text-lg font-semibold mb-4">Reported Users</h2>
          <div className="space-y-3">
            {reports.length === 0 && (
              <p className="text-slate-400 text-sm">No reports yet.</p>
            )}
            {reports.map((report) => (
              <div
                key={report.id}
                className="flex flex-col md:flex-row md:items-center md:justify-between gap-3 bg-slate-800 rounded-xl p-4"
              >
                <div>
                  <p className="text-sm text-slate-300">
                    Reported ID: <span className="font-semibold">{report.reported_id}</span>
                  </p>
                  <p className="text-xs text-slate-400">Reason: {report.reason}</p>
                  <p className="text-xs text-slate-500">
                    Reporter: {report.reporter_id} • {new Date(report.created_at).toLocaleString()}
                  </p>
                </div>
                <button
                  onClick={() => handleBan(report.reported_id)}
                  className="bg-red-500 hover:bg-red-400 transition px-4 py-2 rounded-lg text-sm font-semibold"
                >
                  Ban
                </button>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-slate-900 rounded-2xl p-6">
          <h2 className="text-lg font-semibold mb-4">System Logs</h2>
          <div className="h-96 overflow-y-auto space-y-3 pr-2">
            {logs.length === 0 && (
              <p className="text-slate-400 text-sm">No logs yet.</p>
            )}
            {logs.map((entry) => (
              <div key={entry.id} className="bg-slate-800 rounded-xl p-4">
                <div className="flex items-center justify-between text-xs text-slate-400">
                  <span>{new Date(entry.timestamp).toLocaleString()}</span>
                  <span className="uppercase">{entry.level}</span>
                </div>
                <p className="text-sm text-slate-200 mt-2">{entry.message}</p>
                {entry.meta && (
                  <p className="text-xs text-slate-500 mt-2 break-words">
                    {formatLogMeta(entry.meta)}
                  </p>
                )}
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
