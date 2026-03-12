"""
Cloud System Monitor - Flask Application
Displays detailed system metrics (CPU, GPU, RAM, Disk, Processes) on a web dashboard.
"""

import os
from flask import Flask, render_template, jsonify
import psutil

# GPU support is optional – works only with NVIDIA GPUs
try:
    import GPUtil
    GPU_AVAILABLE = True
except ImportError:
    GPU_AVAILABLE = False

app = Flask(__name__)

# Configuration from environment variables
APP_HOST = os.environ.get("FLASK_HOST", "0.0.0.0")
APP_PORT = int(os.environ.get("FLASK_PORT", 5000))
APP_DEBUG = os.environ.get("FLASK_DEBUG", "false").lower() == "true"


# ── CPU Metrics ─────────────────────────────────────────────
def get_cpu_metrics():
    """Collect detailed CPU metrics including per-core usage and temperatures."""
    per_core = psutil.cpu_percent(interval=1, percpu=True)
    freq = psutil.cpu_freq()
    per_core_freq = psutil.cpu_freq(percpu=True)

    # Temperatures (Linux only in most cases; safe fallback on Windows)
    temps = {}
    try:
        sensor_temps = psutil.sensors_temperatures()
        if sensor_temps:
            for chip, entries in sensor_temps.items():
                temps[chip] = [
                    {
                        "label": e.label or f"Sensor {i}",
                        "current": e.current,
                        "high": e.high,
                        "critical": e.critical,
                    }
                    for i, e in enumerate(entries)
                ]
    except (AttributeError, NotImplementedError):
        pass  # Not available on this OS

    return {
        "percent": psutil.cpu_percent(interval=0),
        "count_logical": psutil.cpu_count(logical=True),
        "count_physical": psutil.cpu_count(logical=False),
        "freq_current": round(freq.current, 0) if freq else None,
        "freq_min": round(freq.min, 0) if freq and freq.min else None,
        "freq_max": round(freq.max, 0) if freq and freq.max else None,
        "per_core_percent": per_core,
        "per_core_freq": [
            {"current": round(f.current, 0), "min": round(f.min, 0) if f.min else None, "max": round(f.max, 0) if f.max else None}
            for f in per_core_freq
        ] if per_core_freq else [],
        "temperatures": temps,
    }


# ── GPU Metrics ─────────────────────────────────────────────
def get_gpu_metrics():
    """Collect GPU metrics using GPUtil (NVIDIA only)."""
    if not GPU_AVAILABLE:
        return {"available": False, "gpus": []}

    try:
        gpus = GPUtil.getGPUs()
        if not gpus:
            return {"available": False, "gpus": []}

        gpu_list = []
        for gpu in gpus:
            gpu_list.append({
                "id": gpu.id,
                "name": gpu.name,
                "load_percent": round(gpu.load * 100, 1),
                "memory_total_mb": round(gpu.memoryTotal, 0),
                "memory_used_mb": round(gpu.memoryUsed, 0),
                "memory_free_mb": round(gpu.memoryFree, 0),
                "memory_percent": round((gpu.memoryUsed / gpu.memoryTotal) * 100, 1) if gpu.memoryTotal > 0 else 0,
                "temperature": gpu.temperature,
                "driver": gpu.driver,
            })
        return {"available": True, "gpus": gpu_list}
    except Exception:
        return {"available": False, "gpus": []}


# ── Memory Metrics ──────────────────────────────────────────
def get_memory_metrics():
    """Collect detailed memory (RAM + Swap) metrics."""
    mem = psutil.virtual_memory()
    swap = psutil.swap_memory()
    return {
        "total": mem.total,
        "available": mem.available,
        "used": mem.used,
        "percent": mem.percent,
        "total_gb": round(mem.total / (1024 ** 3), 2),
        "used_gb": round(mem.used / (1024 ** 3), 2),
        "available_gb": round(mem.available / (1024 ** 3), 2),
        "cached": getattr(mem, "cached", None),
        "cached_gb": round(getattr(mem, "cached", 0) / (1024 ** 3), 2) if getattr(mem, "cached", None) else None,
        "buffers": getattr(mem, "buffers", None),
        "buffers_gb": round(getattr(mem, "buffers", 0) / (1024 ** 3), 2) if getattr(mem, "buffers", None) else None,
        "swap_total_gb": round(swap.total / (1024 ** 3), 2),
        "swap_used_gb": round(swap.used / (1024 ** 3), 2),
        "swap_free_gb": round(swap.free / (1024 ** 3), 2),
        "swap_percent": swap.percent,
    }


# ── Disk Metrics ────────────────────────────────────────────
def get_disk_metrics():
    """Collect disk usage for all mounted partitions."""
    partitions = []
    for part in psutil.disk_partitions(all=False):
        try:
            usage = psutil.disk_usage(part.mountpoint)
            partitions.append({
                "device": part.device,
                "mountpoint": part.mountpoint,
                "fstype": part.fstype,
                "total_gb": round(usage.total / (1024 ** 3), 2),
                "used_gb": round(usage.used / (1024 ** 3), 2),
                "free_gb": round(usage.free / (1024 ** 3), 2),
                "percent": usage.percent,
            })
        except (PermissionError, OSError):
            continue

    # I/O counters
    io = psutil.disk_io_counters()
    io_data = None
    if io:
        io_data = {
            "read_gb": round(io.read_bytes / (1024 ** 3), 2),
            "write_gb": round(io.write_bytes / (1024 ** 3), 2),
            "read_count": io.read_count,
            "write_count": io.write_count,
        }

    # Primary partition summary
    primary = partitions[0] if partitions else {}
    return {
        "percent": primary.get("percent", 0),
        "total_gb": primary.get("total_gb", 0),
        "used_gb": primary.get("used_gb", 0),
        "free_gb": primary.get("free_gb", 0),
        "partitions": partitions,
        "io": io_data,
    }


# ── Process List ────────────────────────────────────────────
def get_top_processes(limit=10):
    """Collect top running processes sorted by memory usage."""
    processes = []
    for proc in psutil.process_iter(["pid", "name", "cpu_percent", "memory_percent"]):
        try:
            info = proc.info
            processes.append({
                "pid": info["pid"],
                "name": info["name"],
                "cpu_percent": round(info["cpu_percent"] or 0, 1),
                "memory_percent": round(info["memory_percent"] or 0, 1),
            })
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            continue
    processes.sort(key=lambda p: p["memory_percent"], reverse=True)
    return processes[:limit]


# ── Routes ──────────────────────────────────────────────────
@app.route("/")
def dashboard():
    """Render the monitoring dashboard."""
    cpu = get_cpu_metrics()
    gpu = get_gpu_metrics()
    memory = get_memory_metrics()
    disk = get_disk_metrics()
    processes = get_top_processes()
    return render_template(
        "index.html",
        cpu=cpu,
        gpu=gpu,
        memory=memory,
        disk=disk,
        processes=processes,
    )


@app.route("/api/metrics")
def api_metrics():
    """Return all system metrics as JSON (for AJAX refresh)."""
    return jsonify({
        "cpu": get_cpu_metrics(),
        "gpu": get_gpu_metrics(),
        "memory": get_memory_metrics(),
        "disk": get_disk_metrics(),
        "processes": get_top_processes(),
    })


@app.route("/health")
def health():
    """Health check endpoint."""
    return jsonify({"status": "healthy"}), 200


if __name__ == "__main__":
    app.run(host=APP_HOST, port=APP_PORT, debug=APP_DEBUG)
