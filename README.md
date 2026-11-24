<p align="center">
<img width="674" height="227" alt="Screenshot 2026-11-23 at 5 29 15 PM" src="https://github.com/user-attachments/assets/5a90ea22-954b-4593-b0e7-89bbc851d44d" />
</p>


# Brazilian-ECommerce-Project-2026
Analyzing late-delivery vs repeat customers using SQL

## Business Question
Is late delivery hurting customer satisfaction and repeat purchases, and which
sellers, product categories, and states drive it? (Olist, 96,203 delivered
orders, Jan 2017 - Aug 2018, ~$13.2M revenue)

## Data Structure 
<img width="3831" height="2268" alt="Mermaid-preview" src="https://github.com/user-attachments/assets/ffd729c5-070b-42ba-9cc8-7ed411e56016" />


## Key Findings
1. **Growth was volume-driven.** Monthly orders rose from 750 to ~7,000 with a
   flat AOV (~$124-152), then plateaued in 2018.
2. **6.8% of orders arrived late, in spikes, not a steady trend.** Nov 2017,
   Feb 2018, and Mar 2018 (12-19% late vs ~3-4% baseline) account for 48% of
   late orders from 22% of volume, and hit every state. RJ and the northeast
   are also chronically worse than SP, MG, and PR.
3. **Lateness hurts satisfaction sharply.** Late orders average 2.27 stars vs
   4.29, and 54% leave 1 star vs 6.6%. Most of the drop occurs within the first
   week late, and the pattern holds in both SP and non-SP.
4. **Repeat purchasing is too low to be the main cost.** Only ~2% of customers
   reorder within 180 days. The late-first-order gap (1.61% vs 2.02%) is
   suggestive, not statistically significant (p ~ 0.09).
5. **Late delivery is diffuse.** The top 25 sellers hold ~7% of late orders,
   and category differences are small (audio is the one clear outlier). The
   worst decile of sellers (43) generates ~$105K of revenue on late orders, ~0.8%
   of total revenue.

## Recommendations
1. Treat late delivery first as a **peak-period operations problem** (capacity
   and carrier contingency planning), since spike months drive about half of it.
2. **Test more conservative delivery estimates** for high-risk states in peak
   months. The review penalty starts right after the promised date, so estimate
   accuracy may protect ratings as much as speed.
3. Manage sellers by **late rate x volume**, starting with the few
   high-volume, high-rate sellers, not the whole worst decile.
4. Justify the work by **customer satisfaction**, not repeat-purchase revenue.

## Limitations and Next Steps
- Correlational analysis; late orders may have other problems (damage, wrong item).
- Canceled and undelivered orders are excluded, so late rates are likely a floor.
- Seller rankings are noisy and were not validated out-of-sample. Next: split-half
  validation, seller-to-customer distance, and a test of whether estimate padding
  would cut 1-star rates.
