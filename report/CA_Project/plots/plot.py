import pandas as pd
import matplotlib.pyplot as plt
import os

# ------------------------
# Read CSV
# ------------------------
df = pd.read_csv("../llc_results.csv")

# Hit rate
df["Hit_Rate"] = df["LLC_Hit"] / df["LLC_Access"] * 100

# ------------------------
# Parse binary names
# ------------------------
parts = df["Binary"].str.extract(
    r"champsim_llc_(\d+)s_(\d+)w_([a-zA-Z0-9]+)_(.+)"
)

df["Sets"] = parts[0].astype(int)
df["Ways"] = parts[1].astype(int)
df["Policy"] = parts[2]
df["Trace"] = parts[3]

policy_order = [
    "lru",
    "mru",
    "random",
    "fifo",
    "ship",
    "srrip",
    "drrip",
    "bip"
]

df["Policy"] = pd.Categorical(
    df["Policy"],
    categories=policy_order,
    ordered=True
)

os.makedirs("plots", exist_ok=True)

# ------------------------
# Hit Rate plots
# ------------------------
for trace in sorted(df["Trace"].unique()):

    plt.figure(figsize=(9,5))

    trace_df = df[df["Trace"] == trace]

    for sets in sorted(trace_df["Sets"].unique()):

        subset = (
            trace_df[trace_df["Sets"] == sets]
            .sort_values("Policy")
        )

        plt.plot(
            subset["Policy"],
            subset["Hit_Rate"],
            marker='o',
            label=f"{sets} sets"
        )

    plt.title(f"{trace} - LLC Hit Rate")
    plt.xlabel("Replacement Policy")
    plt.ylabel("Hit Rate (%)")
    plt.grid(True)
    plt.legend()

    plt.tight_layout()
    plt.savefig(f"plots/{trace}_hit_rate.png")
    plt.close()

# ------------------------
# IPC plots
# ------------------------
for trace in sorted(df["Trace"].unique()):

    plt.figure(figsize=(9,5))

    trace_df = df[df["Trace"] == trace]

    for sets in sorted(trace_df["Sets"].unique()):

        subset = (
            trace_df[trace_df["Sets"] == sets]
            .sort_values("Policy")
        )

        plt.plot(
            subset["Policy"],
            subset["IPC"],
            marker='o',
            label=f"{sets} sets"
        )

    plt.title(f"{trace} - IPC")
    plt.xlabel("Replacement Policy")
    plt.ylabel("IPC")
    plt.grid(True)
    plt.legend()

    plt.tight_layout()
    plt.savefig(f"plots/{trace}_ipc.png")
    plt.close()

print("Plots saved in ./plots")

# import pandas as pd
# import matplotlib.pyplot as plt
# import os

# df = pd.read_csv("../llc_results.csv")

# # Compute hit rate
# df["Hit_Rate"] = df["LLC_Hit"] / df["LLC_Access"] * 100

# # Parse binary name
# parts = df["Binary"].str.extract(
#     r"champsim_llc_(\d+)s_(\d+)w_([a-zA-Z0-9]+)_(.+)"
# )

# df["Sets"] = parts[0].astype(int)
# df["Ways"] = parts[1].astype(int)
# df["Policy"] = parts[2]
# df["Trace"] = parts[3]

# policy_order = [
#     "lru",
#     "mru",
#     "random",
#     "fifo",
#     "ship",
#     "srrip",
#     "drrip",
#     "bip"
# ]

# df["Policy"] = pd.Categorical(
#     df["Policy"],
#     categories=policy_order,
#     ordered=True
# )

# os.makedirs("plots", exist_ok=True)

# # -----------------------------
# # Hit Rate
# # -----------------------------
# for trace in sorted(df["Trace"].unique()):

#     plt.figure(figsize=(9, 5))

#     trace_df = df[df["Trace"] == trace]

#     for policy in policy_order:

#         subset = (
#             trace_df[trace_df["Policy"] == policy]
#             .sort_values("Sets")
#         )

#         plt.plot(
#             subset["Sets"],
#             subset["Hit_Rate"],
#             marker="o",
#             linewidth=2,
#             label=policy.upper()
#         )

#     plt.title(f"{trace} - LLC Hit Rate")
#     plt.xlabel("LLC Sets")
#     plt.ylabel("Hit Rate (%)")
#     plt.xticks([1024, 2048, 4096])
#     plt.grid(True)
#     plt.legend(ncol=2)
#     plt.tight_layout()
#     plt.savefig(f"plots/{trace}_hit_rate.png")
#     plt.close()

# # -----------------------------
# # IPC
# # -----------------------------
# for trace in sorted(df["Trace"].unique()):

#     plt.figure(figsize=(9, 5))

#     trace_df = df[df["Trace"] == trace]

#     for policy in policy_order:

#         subset = (
#             trace_df[trace_df["Policy"] == policy]
#             .sort_values("Sets")
#         )

#         plt.plot(
#             subset["Sets"],
#             subset["IPC"],
#             marker="o",
#             linewidth=2,
#             label=policy.upper()
#         )

#     plt.title(f"{trace} - IPC")
#     plt.xlabel("LLC Sets")
#     plt.ylabel("IPC")
#     plt.xticks([1024, 2048, 4096])
#     plt.grid(True)
#     plt.legend(ncol=2)
#     plt.tight_layout()
#     plt.savefig(f"plots/{trace}_ipc.png")
#     plt.close()

# print("Plots saved to ./plots")