

-- Location entity
CREATE TABLE Location(
    lid INTEGER, -- custom id
    jurisdiction INTEGER,
    location_type VARCHAR2(12),
    ramp_intersection VARCHAR2(50),
    county_city_loc INTEGER,
    population VARCHAR2(30),
    -- Key constraints
    PRIMARY KEY (lid)
);

-- Violation entity
CREATE TABLE Violation(
    vid INTEGER, -- custom id
    pcf_violation INTEGER,
    pcf_violation_category VARCHAR2(33),
    pcf_violation_subsection CHAR(1),
    -- Key constraints
    PRIMARY KEY (vid)
);

-- Conditions entity
CREATE TABLE Conditions(
    cid INTEGER,
    lighting VARCHAR2(39),
    road_surface VARCHAR2(8),
    -- Key constraints
    PRIMARY KEY (cid)
);

-- Collision entity
CREATE TABLE Collision(
    case_id VARCHAR(19),
    datetime TIMESTAMP NOT NULL,
    officer_id VARCHAR2(10), -- allow longer ids if added later
    type_collision CHAR(10),
    process_date DATE,
    primary_collision_factor VARCHAR2(22),
    collision_severity VARCHAR2(20),
    tow_away CHAR(1), -- T/F
    hit_and_run VARCHAR2(15),
    school_bus_related CHAR(1), -- T/F
    lid INTEGER,
    vid INTEGER,
    cid INTEGER,
    -- Key constraints
    PRIMARY KEY (case_id),
    FOREIGN KEY (lid) REFERENCES Location,
    FOREIGN KEY (vid) REFERENCES Violation,
    FOREIGN KEY (cid) REFERENCES Conditions
);

-- Weather entity: ensure 1st normal form
CREATE TABLE Weather(
    case_id VARCHAR(19),
    weather VARCHAR2(7),
    -- Key constraints: composite PK
    PRIMARY KEY (case_id, weather),
    FOREIGN KEY (case_id) REFERENCES COLLISION
                          ON DELETE CASCADE
);

-- Road conditions entity: ensure 1st normal form
CREATE TABLE RoadCondition(
    case_id VARCHAR(19),
    road_cond VARCHAR2(14),
    -- Key constraints: composite PK
    PRIMARY KEY (case_id, road_cond),
    FOREIGN KEY (case_id) REFERENCES COLLISION
                          ON DELETE CASCADE
);

-- Party entity (weak entity)
CREATE TABLE Party(
    pid INTEGER,
    case_id VARCHAR(19),
    party_number INTEGER,
    party_type VARCHAR2(14),
    party_age INTEGER,
    party_sex CHAR(1), -- M/F
    party_sobriety VARCHAR2(37),
    at_fault CHAR(1), -- T/F
    party_drug_physical VARCHAR2(21),
    cellphone_use VARCHAR2(21),
    movement_preceding_collision VARCHAR2(26),
    hazardous_materials CHAR(1), -- T/F
    financial_responsibility VARCHAR2(111),
    -- Key constraints: PK is pid since (case_id, party_num)
    --                  is not sufficient
    PRIMARY KEY (pid),
    FOREIGN KEY (case_id) REFERENCES COLLISION
                  ON DELETE CASCADE
);

CREATE TABLE PartyEquipment(
    pid INTEGER,
    equipment VARCHAR2(37),
    PRIMARY KEY (pid, equipment),
    FOREIGN KEY (pid) REFERENCES Party
                           ON DELETE CASCADE
);

-- Vehicle entity
CREATE TABLE Vehicle(
    pid INTEGER,
    statewide_vehicle_type VARCHAR2(35),
    vehicle_make VARCHAR2(28),
    vehicle_year INTEGER,
    -- Key constraints: the primary key of Party is sufficient
    PRIMARY KEY (pid),
    FOREIGN KEY (pid) REFERENCES Party
                    ON DELETE CASCADE
);

-- Other associated factor entity
CREATE TABLE OtherAssociatedFactor(
    pid INTEGER,
    factor VARCHAR2(29),
    PRIMARY KEY (pid, factor),
    FOREIGN KEY (pid) REFERENCES Party
                                  ON DELETE CASCADE
);

CREATE TABLE Victim(
    vid INTEGER,
    pid INTEGER,
    victim_role VARCHAR2(17),
    victim_age INTEGER,
    victim_ejected VARCHAR2(17),
    victim_sex CHAR(1), -- M/F
    victim_seating_position VARCHAR2(29),
    victim_seating_position_code INTEGER,
    -- Key constraints
    PRIMARY KEY (vid),
    FOREIGN KEY (pid) REFERENCES Party
                   ON DELETE CASCADE
);

CREATE TABLE VictimEquipment(
    vid INTEGER,
    equipment VARCHAR2(37),
    PRIMARY KEY (vid, equipment),
    FOREIGN KEY (vid) REFERENCES Victim
                            ON DELETE CASCADE
);


