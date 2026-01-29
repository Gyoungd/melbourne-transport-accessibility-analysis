# Melbourne Public Transport Accessibility Analysis (2021 GTFS)

## Project Overview
This project analyses the accessibility of Melbourne's public transport system using **Victorian PTV GTFS data (2021)**, the analysis identifies **suburb-level public transport accessibility gaps** and translates them into **accountable, stakeholder-ready insights**.

The focus is. ot infrastructure description, but **decision-support analytics** for transport planning and. ervice equity.

---

## Business Problem
Melbourne's public transport investment decisions are often made without a **quantitative, comparable accessibility metric** at suburb level.

This leads to:
- Uneven service coverage
- Weak multimodal connectivity
- Suburbs with high population or acitivity density being underserved

**Stakeholders need data-backed evidence to prioritise interventions.**

---

## Stakeholders
- **State Transport Planners(PTV / DoT Victoria)**
- **Local Government Planners (City Councils)**
- **Urban & Transport Policy Analysts**

---

## Analytical Objectives
1. Quantify suburb-level public transport accessibility
2. Identify statistically significant service gaps
3. Compare multimodal connectivity (bus / train / tram)
3. Produce insights suitable for executive reporting & visual storytelling

---

## Core Analytical Questions
#### Q1. Do measurable public transport accessibility gaps exist between Melbourne suburbs?
    
```
Which suburbs are well-served, and which are structurally disadvantaged in terms of access to public transport services?
```

**Purpose**
- Identify spaital inequality in service provision
- Establish a baseline for equity-focused planning deicisions

---

## Key Metrics
- Stop Density (per km²)
- Route Diversity Index
- Multimodal Connectivity Ratio
- Accessibility. Composite Score (ACS)

---

## Tech Stack
- PostgreSQL + PostGIS (spatial data processing)
- SQL (analytics & feature engineering)
- Tableau (executive dashboards & poster visuals)
- GitHub (project documentation & reproducibility)

---

## Deliverables
- Analytics-ready database schema
- Metric calculation SQL scripts
- Tableau (executive dashboards & poster visuals)
- GitHub (project documentation & reproducibility)

---

## Data Sources
- Public Transport Victoria (GTFS, 2021)
- ABS boundary data (SA2 / suburb level)

Note: Historical data is used tdo demonstrate **methodology and analytical capability**, not todescribe current service levels.

---

## Data Structure
![GTFS Data Structure](./images/GTFS%20Data%20Structure.jpg)