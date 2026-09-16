# Candidate Offer Specification

## 1. Purpose

This document defines how the company calculates the salary to offer a job
candidate. It is written to be implemented directly as a set of business rules.

The calculation has three steps:

1. Pick the **salary range** for the role the candidate applied to.
2. Pick a **base salary** inside that range, based on the seniority level the
   interview panel assigned.
3. Apply **modifiers** (bonuses and deductions) in a fixed order to produce the
   final offer.

Every rule in this document has an identifier such as `BASE-03` or `MOD-LOC-02`.
Implementations must record the identifier of every rule that fired, so any
offer can be explained after the fact.

## 2. Scope and assumptions

- All amounts are annual gross base salary in USD. Offers outside the US are
  calculated in USD and paid in local currency (`MOD-MKT-93`).
- The output is base salary only. Equity, signing bonus, and variable
  compensation are decided separately and are not covered here.
- The candidate has already completed the interview loop and has a recorded
  seniority evaluation.
- One offer is calculated per candidate per role. If a candidate is considered
  for two roles, the calculation runs twice.

## 3. Inputs

| Field | Type | Required | Notes |
|---|---|---|---|
| `roleCode` | code | yes | One of the roles in section 4 |
| `seniorityScore` | integer 1–100 | yes | From the interview panel, section 5 |
| `marketCode` | code | yes | Location where the candidate will be employed, section 7 |
| `relocationRequired` | boolean | yes | True if the candidate must move to take the job |
| `workMode` | `onsite` / `hybrid` / `remote` | yes | Agreed working arrangement |
| `certifications` | list of codes | no | Recognized certifications, section 8 |
| `yearsExperience` | integer | yes | Total relevant professional experience |
| `currentSalary` | amount | no | Self-reported, used only where local law allows |
| `competingOffer` | amount | no | Verified competing offer, if any |
| `referralSource` | code | no | `employee_referral`, `agency`, `direct`, `inbound` |
| `noticePeriodDays` | integer | no | Days before the candidate can start |
| `visaSponsorshipRequired` | boolean | yes | True if the company must sponsor a work visa |

## 4. Salary ranges per role

Ranges are the company reference ranges, expressed at market index 1.00
(see section 7). All roles in the company are listed.

### 4.1 Engineering

| Role code | Role | Minimum | Midpoint | Maximum |
|---|---|---|---|---|
| `ENG-SWE-1` | Software Engineer I | 95,000 | 110,000 | 125,000 |
| `ENG-SWE-2` | Software Engineer II | 120,000 | 140,000 | 160,000 |
| `ENG-SWE-3` | Senior Software Engineer | 155,000 | 180,000 | 205,000 |
| `ENG-SWE-4` | Staff Software Engineer | 195,000 | 225,000 | 255,000 |
| `ENG-SWE-5` | Principal Software Engineer | 240,000 | 275,000 | 310,000 |
| `ENG-FE-2` | Frontend Engineer | 118,000 | 138,000 | 158,000 |
| `ENG-MOB-2` | Mobile Engineer | 122,000 | 142,000 | 162,000 |
| `ENG-MOB-3` | Senior Mobile Engineer | 158,000 | 183,000 | 208,000 |
| `ENG-EMB-3` | Embedded Systems Engineer | 145,000 | 168,000 | 190,000 |
| `ENG-SRE-2` | Site Reliability Engineer | 125,000 | 145,000 | 165,000 |
| `ENG-SRE-3` | Senior Site Reliability Engineer | 160,000 | 185,000 | 210,000 |
| `ENG-PLT-3` | Platform Engineer | 155,000 | 180,000 | 205,000 |
| `ENG-DAT-2` | Data Engineer | 120,000 | 140,000 | 160,000 |
| `ENG-DAT-3` | Senior Data Engineer | 155,000 | 180,000 | 205,000 |
| `ENG-DBA-2` | Database Administrator | 115,000 | 133,000 | 150,000 |
| `ENG-MLE-3` | Machine Learning Engineer | 165,000 | 195,000 | 225,000 |
| `ENG-MLE-4` | Senior Machine Learning Engineer | 200,000 | 235,000 | 270,000 |
| `ENG-SEC-3` | Security Engineer | 150,000 | 175,000 | 200,000 |
| `ENG-SEC-4` | Senior Security Engineer | 185,000 | 212,000 | 240,000 |
| `ENG-QAE-2` | QA Engineer | 100,000 | 115,000 | 130,000 |
| `ENG-QAE-3` | Senior QA Engineer / SDET | 130,000 | 150,000 | 170,000 |
| `ENG-ARC-4` | Solutions Architect | 175,000 | 200,000 | 225,000 |
| `ENG-DOC-2` | Technical Writer | 95,000 | 110,000 | 125,000 |
| `ENG-DOC-3` | Senior Technical Writer | 120,000 | 138,000 | 155,000 |
| `ENG-DEV-3` | Developer Advocate | 140,000 | 162,000 | 185,000 |
| `ENG-EM-1` | Engineering Manager | 180,000 | 205,000 | 230,000 |
| `ENG-EM-2` | Senior Engineering Manager | 210,000 | 240,000 | 270,000 |
| `ENG-DIR` | Director of Engineering | 250,000 | 290,000 | 330,000 |
| `ENG-VP` | VP of Engineering | 300,000 | 350,000 | 400,000 |
| `ENG-CTO` | Chief Technology Officer | 340,000 | 400,000 | 460,000 |

### 4.2 Product and Design

| Role code | Role | Minimum | Midpoint | Maximum |
|---|---|---|---|---|
| `PRD-PM-1` | Associate Product Manager | 100,000 | 115,000 | 130,000 |
| `PRD-PM-2` | Product Manager | 130,000 | 150,000 | 170,000 |
| `PRD-PM-3` | Senior Product Manager | 160,000 | 185,000 | 210,000 |
| `PRD-PM-4` | Principal Product Manager | 195,000 | 225,000 | 255,000 |
| `PRD-TPM-2` | Technical Program Manager | 130,000 | 152,000 | 175,000 |
| `PRD-TPM-3` | Senior Technical Program Manager | 160,000 | 185,000 | 210,000 |
| `PRD-OPS-2` | Product Operations Manager | 115,000 | 135,000 | 155,000 |
| `PRD-DIR` | Director of Product | 230,000 | 265,000 | 300,000 |
| `PRD-VP` | VP of Product | 290,000 | 335,000 | 380,000 |
| `DES-PD-1` | Product Designer | 105,000 | 125,000 | 145,000 |
| `DES-PD-2` | Senior Product Designer | 140,000 | 165,000 | 190,000 |
| `DES-PD-3` | Staff Product Designer | 175,000 | 200,000 | 225,000 |
| `DES-BRD-2` | Brand Designer | 95,000 | 112,000 | 130,000 |
| `DES-CW-2` | UX Writer / Content Designer | 100,000 | 118,000 | 135,000 |
| `DES-UXR-2` | UX Researcher | 115,000 | 135,000 | 155,000 |
| `DES-UXR-3` | Senior UX Researcher | 145,000 | 168,000 | 190,000 |
| `DES-DIR` | Director of Design | 200,000 | 230,000 | 260,000 |

### 4.3 Data and Analytics

| Role code | Role | Minimum | Midpoint | Maximum |
|---|---|---|---|---|
| `DAT-ANL-1` | Data Analyst | 85,000 | 100,000 | 115,000 |
| `DAT-ANL-2` | Senior Data Analyst | 110,000 | 130,000 | 150,000 |
| `DAT-BI-2` | Business Intelligence Developer | 100,000 | 118,000 | 135,000 |
| `DAT-AE-2` | Analytics Engineer | 120,000 | 140,000 | 160,000 |
| `DAT-DS-2` | Data Scientist | 130,000 | 155,000 | 180,000 |
| `DAT-DS-3` | Senior Data Scientist | 165,000 | 195,000 | 225,000 |
| `DAT-DS-4` | Principal Data Scientist | 205,000 | 240,000 | 275,000 |
| `DAT-ARC-4` | Data Architect | 170,000 | 195,000 | 220,000 |
| `DAT-DIR` | Director of Data | 225,000 | 260,000 | 295,000 |

### 4.4 Sales

| Role code | Role | Minimum | Midpoint | Maximum |
|---|---|---|---|---|
| `GTM-SDR` | Sales Development Representative | 55,000 | 65,000 | 75,000 |
| `GTM-BDR` | Business Development Representative | 58,000 | 68,000 | 78,000 |
| `GTM-SDR-M` | Sales Development Manager | 95,000 | 112,000 | 130,000 |
| `GTM-AE-1` | Account Executive | 80,000 | 95,000 | 110,000 |
| `GTM-AE-2` | Senior Account Executive | 105,000 | 125,000 | 145,000 |
| `GTM-AE-3` | Enterprise Account Executive | 130,000 | 150,000 | 170,000 |
| `GTM-AE-4` | Strategic Account Executive | 150,000 | 172,000 | 195,000 |
| `GTM-SE` | Solutions Engineer | 120,000 | 140,000 | 160,000 |
| `GTM-SE-3` | Senior Solutions Engineer | 150,000 | 172,000 | 195,000 |
| `GTM-SAM` | Sales Manager | 140,000 | 162,000 | 185,000 |
| `GTM-PRT-2` | Partnerships Manager | 120,000 | 140,000 | 160,000 |
| `GTM-PRT-3` | Director of Partnerships | 175,000 | 202,000 | 230,000 |
| `GTM-SOP-2` | Sales Operations Manager | 115,000 | 135,000 | 155,000 |
| `GTM-ROP-3` | Revenue Operations Manager | 130,000 | 152,000 | 175,000 |
| `GTM-SEN-3` | Sales Enablement Manager | 115,000 | 135,000 | 155,000 |
| `GTM-DIR` | Director of Sales | 170,000 | 200,000 | 230,000 |
| `GTM-VP` | VP of Sales | 230,000 | 270,000 | 310,000 |
| `GTM-CRO` | Chief Revenue Officer | 300,000 | 350,000 | 400,000 |

Roles with a commission or variable plan — `GTM-SDR`, `GTM-BDR`, `GTM-AE-1`
through `GTM-AE-4`, `GTM-SAM`, `GTM-PRT-2`, `GTM-PRT-3`, `GTM-DIR`, `GTM-VP`,
`GTM-CRO` — are quoted here as **base salary only**. The variable component is
set by the sales compensation plan and added to the offer letter separately.
Rule `MOD-CMP-07` covers how a competing offer is compared for these roles.

### 4.5 Marketing

| Role code | Role | Minimum | Midpoint | Maximum |
|---|---|---|---|---|
| `GTM-MKT-2` | Marketing Manager | 95,000 | 112,000 | 130,000 |
| `MKT-PMM-2` | Product Marketing Manager | 120,000 | 140,000 | 160,000 |
| `MKT-PMM-3` | Senior Product Marketing Manager | 150,000 | 172,000 | 195,000 |
| `MKT-CNT-2` | Content Marketing Manager | 90,000 | 105,000 | 120,000 |
| `MKT-DMD-2` | Demand Generation Manager | 105,000 | 122,000 | 140,000 |
| `MKT-OPS-2` | Marketing Operations Manager | 105,000 | 122,000 | 140,000 |
| `MKT-EVT-2` | Events Marketing Manager | 90,000 | 105,000 | 120,000 |
| `MKT-COM-3` | Communications and PR Manager | 110,000 | 128,000 | 145,000 |
| `MKT-DIR` | Director of Marketing | 180,000 | 208,000 | 235,000 |
| `MKT-CMO` | Chief Marketing Officer | 280,000 | 320,000 | 360,000 |

### 4.6 Customer Success and Support

| Role code | Role | Minimum | Midpoint | Maximum |
|---|---|---|---|---|
| `GTM-SUP-1` | Technical Support Engineer | 70,000 | 82,000 | 95,000 |
| `CSX-SUP-2` | Senior Technical Support Engineer | 95,000 | 110,000 | 125,000 |
| `CSX-SUP-M` | Support Manager | 115,000 | 135,000 | 155,000 |
| `GTM-CSM` | Customer Success Manager | 85,000 | 100,000 | 115,000 |
| `CSX-CSM-3` | Senior Customer Success Manager | 115,000 | 135,000 | 155,000 |
| `CSX-TAM-3` | Technical Account Manager | 125,000 | 145,000 | 165,000 |
| `CSX-IMP-2` | Implementation Consultant | 100,000 | 118,000 | 135,000 |
| `CSX-PS-3` | Professional Services Manager | 135,000 | 155,000 | 175,000 |
| `CSX-DIR` | Director of Customer Success | 190,000 | 220,000 | 250,000 |

### 4.7 Legal, Risk and Compliance

| Role code | Role | Minimum | Midpoint | Maximum |
|---|---|---|---|---|
| `LEG-PAR-2` | Paralegal | 70,000 | 82,000 | 95,000 |
| `LEG-CON-2` | Contracts Manager | 105,000 | 122,000 | 140,000 |
| `LEG-OPS-2` | Legal Operations Manager | 115,000 | 135,000 | 155,000 |
| `COR-LEG-3` | Corporate Counsel | 165,000 | 195,000 | 225,000 |
| `LEG-CNS-4` | Senior Corporate Counsel | 200,000 | 230,000 | 260,000 |
| `LEG-PRV-3` | Privacy Counsel | 175,000 | 205,000 | 235,000 |
| `LEG-IPC-4` | Intellectual Property Counsel | 210,000 | 245,000 | 280,000 |
| `LEG-CMP-3` | Compliance Manager | 130,000 | 152,000 | 175,000 |
| `LEG-RSK-3` | Risk Manager | 125,000 | 145,000 | 165,000 |
| `LEG-GC` | General Counsel | 280,000 | 330,000 | 380,000 |

### 4.8 Finance and Accounting

| Role code | Role | Minimum | Midpoint | Maximum |
|---|---|---|---|---|
| `FIN-ACC-2` | Staff Accountant | 70,000 | 82,000 | 95,000 |
| `FIN-ACC-3` | Senior Accountant | 95,000 | 110,000 | 125,000 |
| `COR-FIN-2` | Financial Analyst | 90,000 | 105,000 | 120,000 |
| `FIN-FPA-3` | Senior FP&A Analyst | 115,000 | 135,000 | 155,000 |
| `COR-FIN-3` | Finance Manager | 125,000 | 145,000 | 165,000 |
| `FIN-PAY-2` | Payroll Specialist | 65,000 | 76,000 | 88,000 |
| `FIN-PAY-3` | Payroll Manager | 100,000 | 118,000 | 135,000 |
| `FIN-PRC-2` | Procurement Manager | 110,000 | 128,000 | 145,000 |
| `FIN-TAX-3` | Tax Manager | 140,000 | 162,000 | 185,000 |
| `FIN-CTL-4` | Controller | 165,000 | 192,000 | 220,000 |
| `FIN-DIR` | Director of Finance | 190,000 | 220,000 | 250,000 |
| `FIN-CFO` | Chief Financial Officer | 320,000 | 375,000 | 430,000 |

### 4.9 People and Talent

| Role code | Role | Minimum | Midpoint | Maximum |
|---|---|---|---|---|
| `PPL-SRC-2` | Sourcer | 75,000 | 88,000 | 100,000 |
| `COR-REC-2` | Technical Recruiter | 90,000 | 108,000 | 125,000 |
| `PPL-REC-3` | Senior Technical Recruiter | 115,000 | 135,000 | 155,000 |
| `PPL-REC-M` | Recruiting Manager | 140,000 | 162,000 | 185,000 |
| `COR-HR-2` | People Operations Specialist | 80,000 | 95,000 | 110,000 |
| `PPL-HRB-3` | HR Business Partner | 120,000 | 140,000 | 160,000 |
| `PPL-CMP-3` | Compensation and Benefits Manager | 130,000 | 152,000 | 175,000 |
| `PPL-LND-3` | Learning and Development Manager | 115,000 | 135,000 | 155,000 |
| `PPL-DEI-3` | Diversity and Inclusion Program Manager | 115,000 | 135,000 | 155,000 |
| `PPL-DIR` | Director of People | 180,000 | 208,000 | 235,000 |
| `PPL-CPO` | Chief People Officer | 260,000 | 300,000 | 340,000 |

### 4.10 IT and Workplace

| Role code | Role | Minimum | Midpoint | Maximum |
|---|---|---|---|---|
| `ITW-HLP-1` | IT Help Desk Technician | 55,000 | 65,000 | 75,000 |
| `COR-ITS-2` | IT Systems Administrator | 80,000 | 95,000 | 110,000 |
| `ITW-ITS-3` | Senior IT Systems Engineer | 110,000 | 128,000 | 145,000 |
| `ITW-ITM-3` | IT Manager | 135,000 | 155,000 | 175,000 |
| `ITW-OFF-1` | Office Coordinator | 55,000 | 65,000 | 75,000 |
| `ITW-FAC-2` | Workplace and Facilities Manager | 85,000 | 100,000 | 115,000 |

### 4.11 Operations and Executive

| Role code | Role | Minimum | Midpoint | Maximum |
|---|---|---|---|---|
| `OPS-EA-2` | Executive Assistant | 80,000 | 95,000 | 110,000 |
| `COR-OPS-2` | Business Operations Manager | 115,000 | 135,000 | 155,000 |
| `OPS-PMO-3` | Business Program Manager | 125,000 | 145,000 | 165,000 |
| `OPS-STR-3` | Strategy and Operations Lead | 150,000 | 175,000 | 200,000 |
| `OPS-COS-4` | Chief of Staff | 175,000 | 205,000 | 235,000 |
| `EXE-COO` | Chief Operating Officer | 330,000 | 385,000 | 440,000 |

The Chief Executive Officer is not in this table. That offer is set by the
board compensation committee and is outside the scope of this document
(`GRD-08`).

## 5. Seniority evaluation

The interview panel produces a single `seniorityScore` from 1 to 100. The score
places the candidate inside the range of the role they applied for. It does not
change the role.

| Band | Score | Meaning |
|---|---|---|
| Below bar | 1–39 | Does not meet the bar for this role. No offer. |
| Developing | 40–54 | Meets the bar with gaps that need support. |
| Solid | 55–74 | Meets the expectations of the role. |
| Strong | 75–89 | Exceeds expectations in several areas. |
| Exceptional | 90–100 | Clearly above the role; consider the next level up. |

### 5.1 Base salary rules

| ID | Condition | Action |
|---|---|---|
| `BASE-01` | `seniorityScore` < 40 | Stop. No offer is produced. Reason: below hiring bar. |
| `BASE-02` | 40 ≤ `seniorityScore` ≤ 54 | Base is placed in the lower half of the gap between the minimum and the midpoint. |
| `BASE-03` | 55 ≤ `seniorityScore` ≤ 74 | Base is placed between the minimum and the midpoint. |
| `BASE-04` | 75 ≤ `seniorityScore` ≤ 89 | Base is placed between the midpoint and the maximum. |
| `BASE-05` | 90 ≤ `seniorityScore` ≤ 100 | Base is placed in the top quarter of the range. |
| `BASE-06` | `seniorityScore` ≥ 90 and a higher level of the same role family exists | Flag `LEVEL_UP_REVIEW`. The hiring manager must confirm the level before the offer is sent. The calculation still runs on the applied role. |

To keep implementations consistent, all of `BASE-02` through `BASE-05` use one
formula with band-specific anchors:

```
base = lowAnchor + (highAnchor - lowAnchor) * (score - bandLow) / (bandHigh - bandLow)
```

| ID | Band | bandLow | bandHigh | lowAnchor | highAnchor |
|---|---|---|---|---|---|
| `BASE-02` | Developing | 40 | 54 | minimum | minimum + 0.50 × (midpoint − minimum) |
| `BASE-03` | Solid | 55 | 74 | minimum + 0.50 × (midpoint − minimum) | midpoint |
| `BASE-04` | Strong | 75 | 89 | midpoint | midpoint + 0.60 × (maximum − midpoint) |
| `BASE-05` | Exceptional | 90 | 100 | midpoint + 0.60 × (maximum − midpoint) | maximum |

| ID | Rule |
|---|---|
| `BASE-07` | Round the base salary to the nearest 500 before applying any modifier. |

## 6. Modifier rules

Modifiers are applied in the order of their group number. Within a group, all
matching rules apply unless the rule says otherwise. Each modifier is expressed
as a percentage of the **base salary from section 5**, not of the running total,
so the order inside a group does not change the result.

```
finalOffer = round( base × marketIndex + Σ(modifier amounts) )
```

Groups, in order:

1. Market adjustment (section 7)
2. Skills and certifications (section 8)
3. Relocation and work mode (section 9)
4. Experience and supply (section 10)
5. Competitive and negotiation (section 11)
6. Deductions (section 12)
7. Guardrails (section 13)

## 7. Group 1 — Market adjustment

The base salary is multiplied by the market index of the location where the
candidate will be employed. This is the only multiplicative modifier.

The index is relative to the US national baseline of 1.00. Where a country has
both a capital-city entry and a country-wide entry, the more specific one wins
(`MOD-MKT-92`).

### 7.1 North America

| ID | Market code | Location | Index |
|---|---|---|---|
| `MOD-MKT-01` | `US-SF` | United States — San Francisco Bay Area | 1.15 |
| `MOD-MKT-02` | `US-NYC` | United States — New York City | 1.12 |
| `MOD-MKT-03` | `US-SEA` | United States — Seattle | 1.08 |
| `MOD-MKT-04` | `US-BOS` | United States — Boston | 1.05 |
| `MOD-MKT-05` | `US-AUS` | United States — Austin | 1.00 |
| `MOD-MKT-06` | `US-CHI` | United States — Chicago | 1.00 |
| `MOD-MKT-07` | `US-DEN` | United States — Denver | 0.98 |
| `MOD-MKT-08` | `US-OTH` | United States — all other locations | 0.92 |
| `MOD-MKT-09` | `CA-TOR` | Canada — Toronto or Vancouver | 0.88 |
| `MOD-MKT-10` | `CA-OTH` | Canada — all other locations | 0.78 |

### 7.2 United Kingdom and Ireland

| ID | Market code | Location | Index |
|---|---|---|---|
| `MOD-MKT-11` | `UK-LON` | United Kingdom — London | 0.95 |
| `MOD-MKT-12` | `UK-OTH` | United Kingdom — outside London | 0.78 |
| `MOD-MKT-13` | `IE-DUB` | Ireland — Dublin | 0.88 |
| `MOD-MKT-14` | `IE-OTH` | Ireland — outside Dublin | 0.76 |

### 7.3 Western and Northern Europe

| ID | Market code | Location | Index |
|---|---|---|---|
| `MOD-MKT-20` | `CH-ZRH` | Switzerland — Zurich or Geneva | 1.05 |
| `MOD-MKT-21` | `CH-OTH` | Switzerland — other | 0.96 |
| `MOD-MKT-22` | `DE-MUC` | Germany — Munich | 0.88 |
| `MOD-MKT-23` | `DE-BER` | Germany — Berlin | 0.84 |
| `MOD-MKT-24` | `DE-OTH` | Germany — all other locations | 0.80 |
| `MOD-MKT-25` | `NL-AMS` | Netherlands — Amsterdam | 0.87 |
| `MOD-MKT-26` | `NL-OTH` | Netherlands — all other locations | 0.80 |
| `MOD-MKT-27` | `FR-PAR` | France — Paris | 0.82 |
| `MOD-MKT-28` | `FR-OTH` | France — all other locations | 0.72 |
| `MOD-MKT-29` | `BE-BRU` | Belgium — Brussels | 0.80 |
| `MOD-MKT-30` | `BE-OTH` | Belgium — all other locations | 0.74 |
| `MOD-MKT-31` | `LU-LUX` | Luxembourg | 0.90 |
| `MOD-MKT-32` | `AT-VIE` | Austria — Vienna | 0.78 |
| `MOD-MKT-33` | `AT-OTH` | Austria — all other locations | 0.72 |
| `MOD-MKT-34` | `DK-CPH` | Denmark — Copenhagen | 0.88 |
| `MOD-MKT-35` | `SE-STO` | Sweden — Stockholm | 0.82 |
| `MOD-MKT-36` | `SE-OTH` | Sweden — all other locations | 0.74 |
| `MOD-MKT-37` | `NO-OSL` | Norway — Oslo | 0.85 |
| `MOD-MKT-38` | `FI-HEL` | Finland — Helsinki | 0.78 |
| `MOD-MKT-39` | `IS-REY` | Iceland — Reykjavik | 0.78 |

### 7.4 Southern Europe

| ID | Market code | Location | Index |
|---|---|---|---|
| `MOD-MKT-40` | `ES-MAD` | Spain — Madrid or Barcelona | 0.68 |
| `MOD-MKT-41` | `ES-OTH` | Spain — all other locations | 0.60 |
| `MOD-MKT-42` | `PT-LIS` | Portugal — Lisbon or Porto | 0.58 |
| `MOD-MKT-43` | `PT-OTH` | Portugal — all other locations | 0.52 |
| `MOD-MKT-44` | `IT-MIL` | Italy — Milan | 0.68 |
| `MOD-MKT-45` | `IT-OTH` | Italy — all other locations | 0.58 |
| `MOD-MKT-46` | `GR-ATH` | Greece — Athens | 0.52 |
| `MOD-MKT-47` | `CY-NIC` | Cyprus | 0.50 |
| `MOD-MKT-48` | `MT-MLA` | Malta | 0.52 |

### 7.5 Central and Eastern Europe

| ID | Market code | Location | Index |
|---|---|---|---|
| `MOD-MKT-50` | `PL-WAW` | Poland — Warsaw or Krakow | 0.60 |
| `MOD-MKT-51` | `PL-OTH` | Poland — all other locations | 0.52 |
| `MOD-MKT-52` | `CZ-PRG` | Czechia — Prague | 0.60 |
| `MOD-MKT-53` | `CZ-OTH` | Czechia — all other locations | 0.52 |
| `MOD-MKT-54` | `SK-BTS` | Slovakia — Bratislava | 0.52 |
| `MOD-MKT-55` | `HU-BUD` | Hungary — Budapest | 0.52 |
| `MOD-MKT-56` | `RO-BUC` | Romania — Bucharest | 0.50 |
| `MOD-MKT-57` | `RO-OTH` | Romania — all other locations | 0.44 |
| `MOD-MKT-58` | `BG-SOF` | Bulgaria — Sofia | 0.48 |
| `MOD-MKT-59` | `HR-ZAG` | Croatia — Zagreb | 0.48 |
| `MOD-MKT-60` | `SI-LJU` | Slovenia — Ljubljana | 0.55 |
| `MOD-MKT-61` | `RS-BEG` | Serbia — Belgrade | 0.45 |
| `MOD-MKT-62` | `EE-TLL` | Estonia — Tallinn | 0.55 |
| `MOD-MKT-63` | `LV-RIX` | Latvia — Riga | 0.50 |
| `MOD-MKT-64` | `LT-VNO` | Lithuania — Vilnius | 0.52 |
| `MOD-MKT-65` | `UA-KYI` | Ukraine — Kyiv | 0.40 |
| `MOD-MKT-66` | `TR-IST` | Turkey — Istanbul | 0.40 |
| `MOD-MKT-67` | `EU-OTH` | Europe — any country not listed above | 0.55 |

### 7.6 Rest of world

| ID | Market code | Location | Index |
|---|---|---|---|
| `MOD-MKT-70` | `IL-TLV` | Israel — Tel Aviv | 0.92 |
| `MOD-MKT-71` | `AE-DXB` | United Arab Emirates — Dubai | 0.80 |
| `MOD-MKT-72` | `APAC-T1` | APAC Tier 1 — Singapore, Sydney, Tokyo | 0.85 |
| `MOD-MKT-73` | `APAC-T2` | APAC Tier 2 — Bangalore, Manila, Ho Chi Minh City | 0.45 |
| `MOD-MKT-74` | `LATAM-T1` | Latin America Tier 1 — São Paulo, Mexico City, Santiago | 0.58 |
| `MOD-MKT-75` | `LATAM-T2` | Latin America — all other locations | 0.48 |
| `MOD-MKT-76` | `ZA-JNB` | South Africa — Johannesburg or Cape Town | 0.45 |

### 7.7 Market rules

| ID | Rule |
|---|---|
| `MOD-MKT-90` | If `marketCode` is not in the tables above and no country-wide or `EU-OTH` fallback applies, stop and route to Compensation for a manual market index. Reason: unknown market. |
| `MOD-MKT-91` | If the candidate is remote and lives in a different market than the hiring team, use the candidate's market, not the team's. |
| `MOD-MKT-92` | Where several entries could match, apply the most specific one: city first, then country, then the regional fallback (`EU-OTH`, `LATAM-T2`). Record which entry was used. |
| `MOD-MKT-93` | The offer is calculated in USD and converted to the local currency at the FX rate published by Finance for the current quarter. Record the rate used. |
| `MOD-MKT-94` | For a market the company has no legal entity in, the offer is contingent on an employer-of-record arrangement. Flag `EOR_REVIEW`. |

## 8. Group 2 — Skills and certifications

Certification bonuses are one-time additions to base salary, not signing
bonuses. A maximum of two certification bonuses apply per candidate
(`MOD-CRT-90`), taking the two highest.

| ID | Certification code | Certification | Bonus |
|---|---|---|---|
| `MOD-CRT-01` | `CLOUD-PRO` | Cloud provider professional-level architect or engineer | +3% |
| `MOD-CRT-02` | `CLOUD-ASSOC` | Cloud provider associate-level | +1.5% |
| `MOD-CRT-03` | `K8S-CKA` | Certified Kubernetes Administrator or equivalent | +2.5% |
| `MOD-CRT-04` | `SEC-CISSP` | CISSP | +4% |
| `MOD-CRT-05` | `SEC-OSCP` | OSCP | +4% |
| `MOD-CRT-06` | `PM-AGILE` | Recognized product or agile certification | +1% |
| `MOD-CRT-07` | `DATA-PRO` | Recognized data platform professional certification | +2% |
| `MOD-CRT-08` | `PHD-FIELD` | PhD in a field directly relevant to the role | +5% |
| `MOD-CRT-09` | `MS-FIELD` | Master's degree in a field directly relevant to the role | +2% |
| `MOD-CRT-10` | `FIN-CPA` | Certified Public Accountant or national equivalent | +3% |
| `MOD-CRT-11` | `FIN-CFA` | CFA charterholder | +3% |
| `MOD-CRT-12` | `LEG-BAR` | Bar admission in the jurisdiction the role serves | 0% (see `MOD-CRT-94`) |
| `MOD-CRT-13` | `PRV-CIPP` | Privacy certification such as CIPP/E or CIPP/US | +2.5% |
| `MOD-CRT-14` | `HR-SHRM` | SHRM-SCP, SPHR or national HR equivalent | +1.5% |
| `MOD-CRT-15` | `PM-PMP` | Project Management Professional | +1% |
| `MOD-CRT-16` | `SAL-CRM` | Vendor certification on the company's CRM or sales platform | +1% |
| `MOD-CRT-17` | `MKT-ANL` | Recognized marketing analytics or automation certification | +1% |

| ID | Rule |
|---|---|
| `MOD-CRT-90` | At most two certification bonuses apply. Take the two with the highest value. |
| `MOD-CRT-91` | `PHD-FIELD` and `MS-FIELD` are mutually exclusive. Apply only `PHD-FIELD`. |
| `MOD-CRT-92` | A certification only counts if it is relevant to the role, per the mapping in 8.1. A certification outside its mapped roles is recorded and scores 0%. |
| `MOD-CRT-93` | An expired certification does not count. |
| `MOD-CRT-94` | `LEG-BAR` is a prerequisite, not a bonus, for every role in 4.7 whose title contains Counsel. A candidate without it is not eligible; no salary effect either way. |

### 8.1 Certification relevance

| Certification | Counts for |
|---|---|
| `CLOUD-PRO`, `CLOUD-ASSOC` | `ENG-*`, `DAT-*`, `ITW-*`, `COR-ITS-2`, `GTM-SE*` |
| `K8S-CKA` | `ENG-*`, `ITW-ITS-3`, `ITW-ITM-3` |
| `SEC-CISSP`, `SEC-OSCP` | `ENG-SEC-*`, `ENG-SRE-*`, `ITW-*`, `COR-ITS-2`, `LEG-CMP-3`, `LEG-RSK-3` |
| `PM-AGILE` | `PRD-*`, `ENG-EM-*`, `OPS-PMO-3` |
| `PM-PMP` | `PRD-TPM-*`, `OPS-PMO-3`, `OPS-STR-3`, `CSX-PS-3`, `CSX-IMP-2` |
| `DATA-PRO` | `DAT-*`, `ENG-DAT-*`, `ENG-MLE-*`, `ENG-DBA-2` |
| `FIN-CPA`, `FIN-CFA` | `FIN-*`, `COR-FIN-*` |
| `LEG-BAR` | `LEG-*`, `COR-LEG-3` |
| `PRV-CIPP` | `LEG-PRV-3`, `LEG-CMP-3`, `LEG-RSK-3`, `ENG-SEC-*`, `COR-LEG-3` |
| `HR-SHRM` | `PPL-*`, `COR-HR-2`, `COR-REC-2` |
| `SAL-CRM` | `GTM-*`, `MKT-OPS-2`, `CSX-*` |
| `MKT-ANL` | `MKT-*`, `GTM-MKT-2`, `DAT-ANL-*` |
| `PHD-FIELD`, `MS-FIELD` | Any role, if the field is directly relevant |

## 9. Group 3 — Relocation and work mode

| ID | Condition | Modifier |
|---|---|---|
| `MOD-LOC-01` | `relocationRequired` is true and the move is domestic | +4% of base, as a permanent salary uplift |
| `MOD-LOC-02` | `relocationRequired` is true and the move is international | +7% of base |
| `MOD-LOC-03` | `relocationRequired` is true and the destination market index is lower than the candidate's current market index | +3% of base, on top of `MOD-LOC-01` or `MOD-LOC-02`, to soften the drop |
| `MOD-LOC-04` | `workMode` is `onsite` and market is US Tier 1 | +2% of base, commute compensation |
| `MOD-LOC-05` | `workMode` is `remote` and the role is listed as remote-eligible | no change (0%) |
| `MOD-LOC-06` | `workMode` is `hybrid` | no change (0%) |
| `MOD-LOC-07` | `visaSponsorshipRequired` is true | no change to salary. Flag `VISA_REVIEW` so Legal confirms feasibility and timing before the offer is sent. |

Relocation lump-sum payments (moving costs, temporary housing) are handled by
the relocation policy and are not part of this calculation.

## 10. Group 4 — Experience and supply

| ID | Condition | Modifier |
|---|---|---|
| `MOD-EXP-01` | `yearsExperience` is at least 5 years above the role's expected experience | +3% of base |
| `MOD-EXP-02` | `yearsExperience` is more than 3 years below the role's expected experience but `seniorityScore` is 75 or higher | no change. Skill evaluation takes priority over years counted. |
| `MOD-EXP-03` | The role is flagged as a **hard-to-fill** requisition (open more than 90 days, or fewer than 3 candidates reaching final round) | +5% of base |
| `MOD-EXP-04` | The role is flagged as **critical** by the executive team | +8% of base |
| `MOD-EXP-05` | The candidate has direct experience in the company's core domain, confirmed by the panel | +2% of base |
| `MOD-EXP-06` | The candidate is a boomerang: a former employee in good standing who left less than 3 years ago | +2% of base |

| ID | Rule |
|---|---|
| `MOD-EXP-90` | `MOD-EXP-03` and `MOD-EXP-04` are mutually exclusive. Apply only `MOD-EXP-04`. |

## 11. Group 5 — Competitive and negotiation

| ID | Condition | Modifier |
|---|---|---|
| `MOD-CMP-01` | A verified `competingOffer` exceeds the calculated offer by up to 10% | Raise the offer to match the competing offer, capped at the role maximum after market adjustment |
| `MOD-CMP-02` | A verified `competingOffer` exceeds the calculated offer by more than 10% | Do not auto-match. Flag `COMP_ESCALATION` for Compensation review. |
| `MOD-CMP-03` | The competing offer is not verified (no written evidence) | Ignore it. Record that it was considered and not verified. |
| `MOD-CMP-04` | `referralSource` is `employee_referral` | no change to the offer. The referral bonus is paid to the referring employee, not the candidate. |
| `MOD-CMP-05` | `currentSalary` is provided and the jurisdiction bans salary history questions | Discard the value. It must not influence the offer. Record that it was discarded. |
| `MOD-CMP-06` | `noticePeriodDays` is greater than 60 and the requisition is `critical` | no salary change. Flag `START_DATE_REVIEW`. |
| `MOD-CMP-07` | The role carries a commission or variable plan (section 4.4) and a competing offer is quoted as on-target earnings | Compare base to base, not base to OTE. If the competing offer is only available as OTE, flag `OTE_COMPARISON` for Sales Compensation to split. |
| `MOD-CMP-08` | The role is an executive role (`*-CTO`, `*-CFO`, `*-CRO`, `*-CMO`, `*-CPO`, `EXE-COO`, `LEG-GC`, any `*-VP`) | This calculation produces a starting point only. Flag `EXEC_COMP_REVIEW`; the final package is set with the compensation committee. |

## 12. Group 6 — Deductions

| ID | Condition | Modifier |
|---|---|---|
| `MOD-DED-01` | The candidate needs a defined ramp-up plan: `seniorityScore` in the Developing band and the role is level 3 or above | −5% of base |
| `MOD-DED-02` | The candidate is missing a hard requirement of the role and will be trained on it | −3% of base |
| `MOD-DED-03` | The candidate asked for a part-time or reduced schedule | Pro-rate the whole offer by the agreed fraction of full time |
| `MOD-DED-04` | The role's location mandates an employer-funded benefit package well above the US baseline — any market in sections 7.2 through 7.5 | −2% of base. This is partly reflected in the market index already; the deduction covers mandatory employer contributions such as statutory pension, 13th-month pay and extended leave. |
| `MOD-DED-05` | The candidate is hired into a contract-to-hire arrangement | −4% of base for the contract period. Recalculate on conversion. |

## 13. Group 7 — Guardrails

Guardrails run last and can override the result of any earlier group.

| ID | Rule |
|---|---|
| `GRD-01` | The final offer must not fall below the role minimum × market index. If it does, raise it to that floor and record `FLOOR_APPLIED`. |
| `GRD-02` | The final offer must not exceed the role maximum × market index by more than 10%. If it does, cap it and record `CAP_APPLIED`. |
| `GRD-03` | If the final offer exceeds the role maximum × market index at all, require VP approval. Flag `VP_APPROVAL_REQUIRED`. |
| `GRD-04` | The final offer must not exceed the salary of the lowest-paid current employee in the same role and market by more than 10%. If it does, flag `INTERNAL_EQUITY_REVIEW` and hold the offer. |
| `GRD-05` | The final offer must meet the legal minimum wage and any published pay-range floor for the market. If a published range exists for the posting, the offer must fall inside it. |
| `GRD-06` | Round the final offer to the nearest 500. |
| `GRD-07` | An offer with any flag other than `FLOOR_APPLIED` or `CAP_APPLIED` cannot be sent until the flagged review is cleared. |
| `GRD-08` | The Chief Executive Officer role is out of scope. The system returns `NO_OFFER` with reason `BOARD_SET_ROLE`. |

## 14. Output

The system returns one offer record.

| Field | Description |
|---|---|
| `offerAmount` | The annual base salary to offer, in the market currency |
| `currency` | Currency of the amount |
| `roleCode` | Role the offer is for |
| `rangeMin` / `rangeMid` / `rangeMax` | The role range after market adjustment |
| `compaRatio` | `offerAmount` divided by `rangeMid` after market adjustment |
| `baseBeforeModifiers` | The section 5 base salary |
| `appliedRules` | Ordered list of rule identifiers that fired, each with its amount |
| `flags` | List of review flags raised |
| `status` | `READY_TO_SEND`, `PENDING_REVIEW`, or `NO_OFFER` |
| `rationale` | Plain-language explanation, generated from `appliedRules` |

### 14.1 Rationale format

The rationale is one paragraph per group that produced a change, and must name
every rule that fired. Template:

```
Base: {role} range is {min}–{max} at market index 1.00. The panel scored the
candidate {score} ({band}), placing the base at {base} [BASE-0x].

Market: {market} has an index of {index}, giving {adjustedBase} [MOD-MKT-xx].

{One line per applied modifier: rule name, identifier, amount.}

Guardrails: {any guardrail that fired, or "no guardrail changed the result".}

Final offer: {offerAmount}. Compa-ratio {compaRatio}.
```

## 15. Examples

### 15.1 Example A — Senior Software Engineer, strong panel, Austin, no relocation

Input: `ENG-SWE-3`, score 80, `US-AUS`, no relocation, hybrid, no
certifications, 9 years experience, standard requisition.

| Step | Rule | Calculation | Result |
|---|---|---|---|
| Base | `BASE-04` | midpoint 180,000 + 0.60 × (205,000 − 180,000) × (80 − 75)/(89 − 75) = 180,000 + 15,000 × 0.357 | 185,357 |
| Round | `BASE-07` | nearest 500 | 185,500 |
| Market | `MOD-MKT-05` | 185,500 × 1.00 | 185,500 |
| Work mode | `MOD-LOC-06` | hybrid, no change | 185,500 |
| Guardrails | `GRD-06` | already rounded | 185,500 |

**Offer: 185,500 USD.** Compa-ratio 1.03. Status `READY_TO_SEND`.

Rationale: the Senior Software Engineer range is 155,000–205,000. The panel
scored the candidate 80 (Strong), placing the base at 185,500 `[BASE-04]`.
Austin has a market index of 1.00 `[MOD-MKT-05]`. Hybrid work adds nothing
`[MOD-LOC-06]`. No guardrail changed the result.

### 15.2 Example B — Security Engineer, relocating internationally to San Francisco, CISSP

Input: `ENG-SEC-3`, score 72, `US-SF`, relocation required and international,
onsite, certifications `SEC-CISSP` and `CLOUD-ASSOC`, 8 years experience,
hard-to-fill requisition.

| Step | Rule | Calculation | Result |
|---|---|---|---|
| Base | `BASE-03` | low anchor 150,000 + 0.50 × (175,000 − 150,000) = 162,500; high anchor 175,000; 162,500 + 12,500 × (72 − 55)/(74 − 55) | 173,684 |
| Round | `BASE-07` | nearest 500 | 173,500 |
| Market | `MOD-MKT-01` | 173,500 × 1.15 | 199,525 |
| Certification | `MOD-CRT-04` | +4% of 173,500 (CISSP, relevant to `ENG-SEC`) | +6,940 |
| Certification | `MOD-CRT-02` | +1.5% of 173,500 | +2,603 |
| Cert cap | `MOD-CRT-90` | two certifications, both apply | — |
| Relocation | `MOD-LOC-02` | +7% of 173,500, international move | +12,145 |
| Onsite | `MOD-LOC-04` | +2% of 173,500, US Tier 1 onsite | +3,470 |
| Hard to fill | `MOD-EXP-03` | +5% of 173,500 | +8,675 |
| Visa | `MOD-LOC-07` | flag `VISA_REVIEW` | — |
| Subtotal | | 199,525 + 6,940 + 2,603 + 12,145 + 3,470 + 8,675 | 233,358 |
| Cap check | `GRD-02` | maximum 200,000 × 1.15 = 230,000; +10% ceiling = 253,000. Under ceiling. | 233,358 |
| Approval | `GRD-03` | above 230,000, flag `VP_APPROVAL_REQUIRED` | — |
| Round | `GRD-06` | nearest 500 | 233,500 |

**Offer: 233,500 USD.** Compa-ratio 1.16. Status `PENDING_REVIEW`, flags
`VISA_REVIEW` and `VP_APPROVAL_REQUIRED`.

### 15.3 Example C — Data Analyst, developing band, remote from Madrid

Input: `DAT-ANL-1`, score 48, `ES-MAD`, no relocation, remote, no
certifications, 2 years experience, standard requisition.

| Step | Rule | Calculation | Result |
|---|---|---|---|
| Base | `BASE-02` | 85,000 + 0.50 × (100,000 − 85,000) = 7,500 span; 85,000 + 7,500 × (48 − 40)/(54 − 40) | 89,286 |
| Round | `BASE-07` | nearest 500 | 89,500 |
| Market | `MOD-MKT-40` | 89,500 × 0.68 | 60,860 |
| Remote | `MOD-LOC-05` | remote-eligible, no change | 60,860 |
| Benefits | `MOD-DED-04` | −2% of 89,500 | −1,790 |
| Ramp-up | `MOD-DED-01` | does not apply; role is level 1, not level 3+ | — |
| Subtotal | | 60,860 − 1,790 | 59,070 |
| Floor | `GRD-01` | minimum 85,000 × 0.68 = 57,800. Above floor. | 59,070 |
| Round | `GRD-06` | nearest 500 | 59,000 |

**Offer: 59,000 USD, paid in EUR at the published quarterly FX rate
`[MOD-MKT-93]`.** Compa-ratio 0.87. Status `READY_TO_SEND`.

### 15.4 Example D — Exceptional candidate, level-up review

Input: `ENG-SWE-2`, score 94, `US-NYC`, no relocation, hybrid, `MS-FIELD`,
7 years experience, critical requisition.

| Step | Rule | Calculation | Result |
|---|---|---|---|
| Base | `BASE-05` | low anchor 140,000 + 0.60 × (160,000 − 140,000) = 152,000; high anchor 160,000; 152,000 + 8,000 × (94 − 90)/(100 − 90) | 155,200 |
| Level up | `BASE-06` | `ENG-SWE-3` exists, flag `LEVEL_UP_REVIEW` | — |
| Round | `BASE-07` | nearest 500 | 155,000 |
| Market | `MOD-MKT-02` | 155,000 × 1.12 | 173,600 |
| Certification | `MOD-CRT-09` | +2% of 155,000 | +3,100 |
| Experience | `MOD-EXP-01` | 7 years is not 5 above the expected 3–6 for SWE II; does not apply | — |
| Critical | `MOD-EXP-04` | +8% of 155,000 | +12,400 |
| Subtotal | | 173,600 + 3,100 + 12,400 | 189,100 |
| Cap check | `GRD-02` | maximum 160,000 × 1.12 = 179,200; +10% ceiling = 197,120. Under ceiling. | 189,100 |
| Approval | `GRD-03` | above 179,200, flag `VP_APPROVAL_REQUIRED` | — |
| Round | `GRD-06` | nearest 500 | 189,000 |

**Offer: 189,000 USD.** Compa-ratio 1.21. Status `PENDING_REVIEW`, flags
`LEVEL_UP_REVIEW` and `VP_APPROVAL_REQUIRED`.

The `LEVEL_UP_REVIEW` flag is the important one here: a score of 94 against
SWE II suggests the candidate should be offered `ENG-SWE-3` instead, where the
same calculation would produce a different and probably better offer. The
hiring manager decides before the offer is sent.

### 15.5 Example E — Enterprise Account Executive, Berlin, commission role

Input: `GTM-AE-3`, score 78, `DE-BER`, no relocation, remote, certification
`SAL-CRM`, 9 years experience, hard-to-fill requisition, candidate quoted a
competing offer as on-target earnings.

| Step | Rule | Calculation | Result |
|---|---|---|---|
| Base | `BASE-04` | midpoint 150,000 + 0.60 × (170,000 − 150,000) × (78 − 75)/(89 − 75) | 152,571 |
| Round | `BASE-07` | nearest 500 | 152,500 |
| Market | `MOD-MKT-23` | 152,500 × 0.84 (Berlin) | 128,100 |
| Certification | `MOD-CRT-16` | +1% of 152,500, CRM platform certification | +1,525 |
| Hard to fill | `MOD-EXP-03` | +5% of 152,500 | +7,625 |
| Benefits | `MOD-DED-04` | −2% of 152,500, German statutory employer contributions | −3,050 |
| Competing offer | `MOD-CMP-07` | quoted as OTE, flag `OTE_COMPARISON` | — |
| Subtotal | | 128,100 + 1,525 + 7,625 − 3,050 | 134,200 |
| Floor | `GRD-01` | minimum 130,000 × 0.84 = 109,200. Above floor. | 134,200 |
| Cap | `GRD-02` | maximum 170,000 × 0.84 = 142,800. Under maximum. | 134,200 |
| Round | `GRD-06` | nearest 500 | 134,000 |

**Offer: 134,000 USD, paid in EUR `[MOD-MKT-93]`.** Compa-ratio 1.07.
Status `PENDING_REVIEW`, flag `OTE_COMPARISON`.

This is base salary only. The commission plan is quoted separately in the offer
letter, and `MOD-CMP-07` stops the system from comparing our base against the
candidate's on-target earnings, which would overstate what they are being
offered elsewhere.

### 15.6 Example F — Corporate Counsel relocating from New York to Dublin

Input: `COR-LEG-3`, score 68, `IE-DUB`, relocation required and international,
onsite, certifications `LEG-BAR` and `PRV-CIPP`, 7 years experience, currently
employed in `US-NYC`, work permit needed.

| Step | Rule | Calculation | Result |
|---|---|---|---|
| Base | `BASE-03` | low anchor 165,000 + 0.50 × (195,000 − 165,000) = 180,000; high anchor 195,000; 180,000 + 15,000 × (68 − 55)/(74 − 55) | 190,263 |
| Round | `BASE-07` | nearest 500 | 190,500 |
| Market | `MOD-MKT-13` | 190,500 × 0.88 (Dublin) | 167,640 |
| Bar admission | `MOD-CRT-94` | prerequisite for a Counsel role, no salary effect | 0 |
| Certification | `MOD-CRT-13` | +2.5% of 190,500, privacy certification | +4,763 |
| Relocation | `MOD-LOC-02` | +7% of 190,500, international move | +13,335 |
| Index drop | `MOD-LOC-03` | +3% of 190,500, destination index 0.88 is below the candidate's current 1.12 | +5,715 |
| Onsite | `MOD-LOC-04` | applies to US Tier 1 only, not Dublin | 0 |
| Benefits | `MOD-DED-04` | −2% of 190,500, Irish statutory contributions | −3,810 |
| Work permit | `MOD-LOC-07` | flag `VISA_REVIEW` | — |
| Subtotal | | 167,640 + 4,763 + 13,335 + 5,715 − 3,810 | 187,643 |
| Cap | `GRD-02` | maximum 225,000 × 0.88 = 198,000. Under maximum. | 187,643 |
| Round | `GRD-06` | nearest 500 | 187,500 |

**Offer: 187,500 USD, paid in EUR `[MOD-MKT-93]`.** Compa-ratio 1.09.
Status `PENDING_REVIEW`, flag `VISA_REVIEW`.

Two rules carry most of the weight here. `MOD-LOC-03` recognizes that Dublin's
index is well below New York's, so a straight market conversion would read as a
pay cut. `MOD-CRT-94` records the bar admission without paying a bonus for it,
because the role cannot be filled without it.

### 15.7 Example G — Below the bar

Input: `PRD-PM-2`, score 34, `US-SEA`.

| Step | Rule | Result |
|---|---|---|
| Base | `BASE-01` | Stop. No offer. |

**Status `NO_OFFER`.** Rationale: the panel scored the candidate 34, below the
hiring bar of 40 for Product Manager `[BASE-01]`. No salary is calculated.

## 16. Maintenance

| ID | Rule |
|---|---|
| `GOV-01` | Salary ranges in section 4 are reviewed once a year against market survey data, and republished with a version date. |
| `GOV-02` | Market indices in section 7 are reviewed twice a year. |
| `GOV-03` | A change to any rule requires a new version of this document. Offers already sent are not recalculated. |
| `GOV-05` | Role codes are permanent. A role that is renamed or moved to a different section keeps its code, and a retired code is never reused for a different role. This is why some codes carry a prefix from an earlier grouping, such as `GTM-MKT-2` in Marketing and `COR-ITS-2` in IT. |
| `GOV-06` | A new role must be added to section 4 with a range before any offer can be calculated for it. The system does not infer a range from a similar role. |
| `GOV-04` | Every calculation is stored with the document version, the inputs, and the full `appliedRules` list, and kept for the period required by local employment law. |
