/// Resource snapshot containing all collected metrics
class ResourceSnapshot {
  const ResourceSnapshot({
    required this.cpuUsage,
    required this.load1,
    required this.load5,
    required this.load15,
    required this.memoryTotalGb,
    required this.memoryUsedGb,
    required this.memoryUsedPct,
    required this.swapTotalGb,
    required this.swapUsedGb,
    required this.swapUsedPct,
    required this.disks,
    required this.processes,
    required this.netInMbps,
    required this.netOutMbps,
    required this.totalDiskIo,
    required this.netTotals,
  });

  final double cpuUsage;
  final double load1;
  final double load5;
  final double load15;
  final double memoryTotalGb;
  final double memoryUsedGb;
  final double memoryUsedPct;
  final double swapTotalGb;
  final double swapUsedGb;
  final double swapUsedPct;
  final List<DiskUsage> disks;
  final List<ProcessInfo> processes;
  final double netInMbps;
  final double netOutMbps;
  final double totalDiskIo;
  final NetTotals netTotals;
}

/// Disk usage information
class DiskUsage {
  const DiskUsage({
    required this.filesystem,
    required this.usedGb,
    required this.totalGb,
    required this.usedPct,
    required this.readMbps,
    required this.writeMbps,
  });

  final String filesystem;
  final double usedGb;
  final double totalGb;
  final double usedPct;
  final double readMbps;
  final double writeMbps;

  String get name => filesystem.split('/').last;
  double get freeGb => (totalGb - usedGb).clamp(0, double.infinity);
}

/// Process information
class ProcessInfo {
  const ProcessInfo({
    required this.pid,
    required this.ppid,
    required this.command,
    required this.cpu,
    required this.memoryPercent,
    required this.memoryBytes,
  });

  final int pid;
  final int ppid;
  final String command;
  final double cpu;
  final double memoryPercent;
  final double memoryBytes;
}

/// Memory statistics
class MemStats {
  const MemStats({
    required this.totalGb,
    required this.usedGb,
    required this.usedPct,
    required this.swapTotalGb,
    required this.swapUsedGb,
    required this.swapUsedPct,
  });

  final double totalGb;
  final double usedGb;
  final double usedPct;
  final double swapTotalGb;
  final double swapUsedGb;
  final double swapUsedPct;
}

/// Network totals
class NetTotals {
  const NetTotals({
    required this.rxBytes,
    required this.txBytes,
    required this.timestamp,
  });

  final int rxBytes;
  final int txBytes;
  final DateTime timestamp;
}

/// Disk IO rate
class DiskIoRate {
  const DiskIoRate({required this.readMbps, required this.writeMbps});

  final double readMbps;
  final double writeMbps;
}

/// Disk stat sample
class DiskStatSample {
  const DiskStatSample({
    required this.readSectors,
    required this.writeSectors,
  });

  final int readSectors;
  final int writeSectors;
}

