import Foundation

public enum HousekeepConfig {
    /// Cache/build directory names considered reclaimable. Matches bash's `CACHE_PATTERNS`.
    public static let cachePatterns: [String] = [
        "node_modules", ".venv", "venv", "__pycache__",
        ".next", "dist", "build", "target",
        ".gradle", "DerivedData", ".turbo",
    ]

    /// `find`'s `-maxdepth` used by every scanner. Kept as one constant since bash hardcoded
    /// `4` independently in each of run_space/run_security/run_git/fix_git/fix_security.
    public static let maxDepth = 4
}
