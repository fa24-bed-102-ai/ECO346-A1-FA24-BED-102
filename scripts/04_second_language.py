# Question 5: band table and literacy figure in Python (variant 2 = Sindh rural)
# Run from the repository root:  python scripts/04_second_language.py
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

os.makedirs("figures", exist_ok=True)

# 1. Read the local data and attach hhweight, prov_code, urban_rural by hhid
person = pd.read_csv("data/pslm_person_subset.csv")
hh = pd.read_csv("data/pslm_hh_subset.csv")
d = person.merge(hh[["hhid", "hhweight", "prov_code", "urban_rural"]],
                 on="hhid", how="left")

# 2. Variant 2 = Sindh (prov_code 3) rural (urban_rural 1)
d = d[(d["prov_code"] == 3) & (d["urban_rural"] == 1)]

# 3. Literacy sample: aged 10-64, literate not missing
lit = d[(d["age"] >= 10) & (d["age"] <= 64) & d["literate"].notna()].copy()
lit["band_start"] = (lit["age"] // 5) * 5
lit["mid"] = lit["band_start"] + 2
lit["sex_label"] = lit["sex"].map({1: "Men", 2: "Women"})

# 4. Band table: unweighted n and weighted literacy rate for each band and sex
def summarise(t):
    return pd.Series({
        "n": len(t),
        "rate": 100 * np.average(t["literate"], weights=t["hhweight"]),
    })

tab = (lit.groupby(["band_start", "mid", "sex_label"])
          .apply(summarise, include_groups=False)
          .reset_index())
tab["thin"] = tab["n"] < 30
tab["rate"] = tab["rate"].round(1)
tab["n"] = tab["n"].astype(int)
tab.to_csv("figures/band_table_python.csv", index=False)

wide = tab.pivot(index=["band_start", "mid"], columns="sex_label", values="rate").reset_index()
wide["gap"] = (wide["Men"] - wide["Women"]).round(1)
best = wide.loc[wide["gap"].idxmax()]
print(tab.to_string(index=False))
print("Largest gap: band", int(best["band_start"]), "-", int(best["band_start"]) + 4,
      "gap =", best["gap"])
print("Women 15-19:", wide.loc[wide.band_start == 15, "Women"].values[0])

# 5. Figure
colors = {"Men": "#1f77b4", "Women": "#d95f02"}
fig, ax = plt.subplots(figsize=(8, 5))
for sex, g in tab.groupby("sex_label"):
    g = g.sort_values("mid")
    ax.plot(g["mid"], g["rate"], color=colors[sex], lw=2, zorder=2)
    for _, r in g.iterrows():
        ax.plot(r["mid"], r["rate"], "o", ms=7, color=colors[sex],
                markerfacecolor="white" if r["thin"] else colors[sex], zorder=3)
    last = g.iloc[-1]
    ax.text(last["mid"] + 1, last["rate"], sex, color=colors[sex],
            va="center", ha="left", fontweight="bold")

# annotate the band with the largest gap
ax.plot([best["mid"]] * 2, [best["Women"], best["Men"]], color="grey", lw=1.2, ls=":")
ax.text(best["mid"] + 0.8, (best["Women"] + best["Men"]) / 2,
        f"Largest gap: {best['gap']:.1f} points\n(ages {int(best['band_start'])}-{int(best['band_start'])+4})",
        va="center", ha="left", fontsize=9, color="#333333")

ax.set_ylim(0, 100)
ax.set_xlim(10, 70)
ax.set_xticks([12 + 5 * i for i in range(11)])
ax.set_xlabel("Age band (plotted at midpoint)")
ax.set_ylabel("Literacy rate (%)")
ax.set_title("Literacy falls with age for rural Sindh women, far faster than for men", loc="left", fontsize=12)
for s in ["top", "right"]:
    ax.spines[s].set_visible(False)
fig.text(0.01, 0.01,
         "Source: PSLM 2019-20, person file. Sample: persons aged 10-64, rural Sindh, literate not missing.\n"
         "Weighted by household weight (hhweight). Hollow markers = fewer than 30 observations.",
         fontsize=7.5, color="#444444", ha="left", va="bottom")
fig.tight_layout(rect=(0, 0.07, 1, 1))
plt.savefig("figures/literacy_by_age_python.svg")
