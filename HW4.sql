CREATE DATABASE IF NOT EXISTS global_space;
USE global_space;
-- Name: Najeeb Phillips
-- Assignment: HW4 — Global Space Missions

CREATE TABLE countries (
    countrycode CHAR(3) NOT NULL,
    countryname VARCHAR(100) NOT NULL,
    continent VARCHAR(50) NOT NULL,
    PRIMARY KEY (countrycode)
) ENGINE = InnoDB;
-- Each organization belongs to a headquarters country.
-- Country code changes cascade; referenced countries cannot be deleted.
CREATE TABLE organizations (
    orgid INT NOT NULL,
    orgname VARCHAR(150) NOT NULL,
    headquarterscountry CHAR(3) NOT NULL,
    orgtype VARCHAR(30) NOT NULL,
    PRIMARY KEY (orgid),
    CONSTRAINT fk_organizations_country
        FOREIGN KEY (headquarterscountry)
        REFERENCES countries (countrycode)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE = InnoDB;
-- Each launch site belongs to a host country.
-- Referenced countries cannot be deleted; code updates cascade.
CREATE TABLE launch_sites (
    siteid INT NOT NULL,
    sitename VARCHAR(150) NOT NULL,
    countrycode CHAR(3) NOT NULL,
    status VARCHAR(30) NOT NULL,
    PRIMARY KEY (siteid),
    CONSTRAINT fk_launch_sites_country
        FOREIGN KEY (countrycode)
        REFERENCES countries (countrycode)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE = InnoDB;
-- Each rocket references its manufacturing organization.
-- Organization ID updates cascade; referenced organizations cannot be deleted.
CREATE TABLE rockets (
    rocketid INT NOT NULL,
    rocketname VARCHAR(100) NOT NULL,
    orgid INT NOT NULL,
    payloadcapacitykg DECIMAL(12,2) NOT NULL,
    operationalstatus VARCHAR(30) NOT NULL,
    PRIMARY KEY (rocketid),
    CONSTRAINT fk_rockets_organization
        FOREIGN KEY (orgid)
        REFERENCES organizations (orgid)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE = InnoDB;
-- Each mission references a rocket and a launch site.
-- Key updates cascade; referenced rockets and sites cannot be deleted.
CREATE TABLE missions (
    missionid INT NOT NULL,
    missionname VARCHAR(150) NOT NULL,
    rocketid INT NOT NULL,
    siteid INT NOT NULL,
    destination VARCHAR(50) NOT NULL,
    launchyear SMALLINT NOT NULL,
    outcome VARCHAR(30) NOT NULL,
    PRIMARY KEY (missionid),
    CONSTRAINT fk_missions_rocket
        FOREIGN KEY (rocketid)
        REFERENCES rockets (rocketid)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_missions_launch_site
        FOREIGN KEY (siteid)
        REFERENCES launch_sites (siteid)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE = InnoDB;
-- Each payload belongs to a mission.
-- Mission ID updates cascade.
-- Deleting a mission also deletes its payload records.
CREATE TABLE payloads (
    payloadid INT NOT NULL,
    missionid INT NOT NULL,
    payloadname VARCHAR(150) NOT NULL,
    payloadtype VARCHAR(50) NOT NULL,
    masskg DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (payloadid),
    CONSTRAINT fk_payloads_mission
        FOREIGN KEY (missionid)
        REFERENCES missions (missionid)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE = InnoDB;
-- Query 1: List all missions with rocket, organization, and launch site.
-- Sort by newest launch year, then alphabetically by mission name.
SELECT missions.missionname,
       rockets.rocketname,
       organizations.orgname,
       launch_sites.sitename,
       missions.destination,
       missions.launchyear,
       missions.outcome
FROM missions
INNER JOIN rockets
    ON missions.rocketid = rockets.rocketid
INNER JOIN organizations
    ON rockets.orgid = organizations.orgid
INNER JOIN launch_sites
    ON missions.siteid = launch_sites.siteid
ORDER BY missions.launchyear DESC,
         missions.missionname ASC;
         -- Query 2: Show payloads launched in 2024, heaviest first.
SELECT missions.missionname,
       rockets.rocketname,
       payloads.payloadname,
       payloads.payloadtype,
       payloads.masskg
FROM payloads
INNER JOIN missions
    ON payloads.missionid = missions.missionid
INNER JOIN rockets
    ON missions.rocketid = rockets.rocketid
WHERE missions.launchyear = 2024
ORDER BY payloads.masskg DESC;
-- Query 3: Include every launch site, even without a 2024 mission.
SELECT launch_sites.sitename,
       missions.missionname,
       rockets.rocketname,
       missions.launchyear
FROM launch_sites
LEFT JOIN missions
    ON launch_sites.siteid = missions.siteid
    AND missions.launchyear = 2024
LEFT JOIN rockets
    ON missions.rocketid = rockets.rocketid
ORDER BY launch_sites.sitename ASC;
-- Query 4: Calculate total payload mass per organization using a CTE.
-- Include organizations with no payloads as zero.
WITH organization_payload_totals AS (
    SELECT rockets.orgid,
           SUM(payloads.masskg) AS totalpayloadmasskg
    FROM rockets
    INNER JOIN missions
        ON rockets.rocketid = missions.rocketid
    INNER JOIN payloads
        ON missions.missionid = payloads.missionid
    GROUP BY rockets.orgid
)
SELECT organizations.orgname,
       organizations.headquarterscountry,
       organizations.orgtype,
       COALESCE(organization_payload_totals.totalpayloadmasskg, 0)
           AS totalpayloadmasskg
FROM organizations
LEFT JOIN organization_payload_totals
    ON organizations.orgid = organization_payload_totals.orgid
ORDER BY totalpayloadmasskg DESC;
-- Query 5: Use two CTEs to summarize missions and payload mass.
-- Country means the host country of the launch site.
-- Separate totals prevent multiple payloads from inflating mission counts.
WITH country_mission_totals AS (
    SELECT launch_sites.countrycode,
           COUNT(missions.missionid) AS totalmissions
    FROM launch_sites
    INNER JOIN missions
        ON launch_sites.siteid = missions.siteid
    GROUP BY launch_sites.countrycode
),
country_payload_totals AS (
    SELECT launch_sites.countrycode,
           SUM(payloads.masskg) AS totalpayloadmasskg
    FROM launch_sites
    INNER JOIN missions
        ON launch_sites.siteid = missions.siteid
    INNER JOIN payloads
        ON missions.missionid = payloads.missionid
    GROUP BY launch_sites.countrycode
)
SELECT countries.countryname,
       COALESCE(country_mission_totals.totalmissions, 0)
           AS totalmissions,
       COALESCE(country_payload_totals.totalpayloadmasskg, 0)
           AS totalpayloadmasskg
FROM countries
LEFT JOIN country_mission_totals
    ON countries.countrycode = country_mission_totals.countrycode
LEFT JOIN country_payload_totals
    ON countries.countrycode = country_payload_totals.countrycode
ORDER BY totalpayloadmasskg DESC;