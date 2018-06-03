SET FOREIGN_KEY_CHECKS=0; # Allow us to delete the table without worrying about forreign keys

# Drop all the tables
DROP TABLE IF EXISTS Route CASCADE;
DROP TABLE IF EXISTS Airport CASCADE;
DROP TABLE IF EXISTS WeeklyFlight CASCADE;
DROP TABLE IF EXISTS Year CASCADE;
DROP TABLE IF EXISTS WeekDay CASCADE;
DROP TABLE IF EXISTS Flight CASCADE;
DROP TABLE IF EXISTS Reservation CASCADE;
DROP TABLE IF EXISTS Seat CASCADE;
DROP TABLE IF EXISTS Passenger CASCADE;
DROP TABLE IF EXISTS Ticket CASCADE;
DROP TABLE IF EXISTS Contact CASCADE;
DROP TABLE IF EXISTS Booking CASCADE;
DROP TABLE IF EXISTS CreditCard CASCADE;

# Drop all the procedures
DROP PROCEDURE IF EXISTS addYear;
DROP PROCEDURE IF EXISTS addDay;
DROP PROCEDURE IF EXISTS addDestination;
DROP PROCEDURE IF EXISTS addRoute;
DROP PROCEDURE IF EXISTS addFlight;
DROP PROCEDURE IF EXISTS addReservation;
DROP PROCEDURE IF EXISTS addPassenger;
DROP PROCEDURE IF EXISTS addContact;
DROP PROCEDURE IF EXISTS addPayment;

# Drop all the functions
DROP FUNCTION IF EXISTS calculateFreeSeats;
DROP FUNCTION IF EXISTS calculatePrice;

# Drop the view
DROP VIEW IF EXISTS allFlights;

# Re-enable the foreign key control
SET FOREIGN_KEY_CHECKS=1;

# Creating all the tables
CREATE TABLE Route # Route between 2 airports for a given year
    (rid INT NOT NULL AUTO_INCREMENT,
     rdeparture_airport VARCHAR(3) NOT NULL,
     rarrival_airport VARCHAR(3) NOT NULL,
     rprice DOUBLE,
     ryear INT,
     CONSTRAINT pk_route PRIMARY KEY(rid)) ENGINE=InnoDB;

CREATE TABLE Airport
    (acode VARCHAR(3),
     aname VARCHAR(30),
     acountry VARCHAR(30),
     CONSTRAINT pk_airport PRIMARY KEY(acode)) ENGINE=InnoDB;

CREATE TABLE WeeklyFlight # A flight schedule that repeats every week of a given year
    (wfid INT NOT NULL AUTO_INCREMENT,
     wfdtime TIME,
     wfday VARCHAR(10),
     wfyear INT NOT NULL,
     wfrouteid INT NOT NULL,
     CONSTRAINT pk_weekly_flight PRIMARY KEY(wfid)) ENGINE=InnoDB;

CREATE TABLE Year
    (yyear INT,
     yprofit_factor DOUBLE,
     CONSTRAINT pk_year PRIMARY KEY(yyear)) ENGINE=InnoDB;

CREATE TABLE WeekDay
    (wdname VARCHAR(10),
     wdfactor DOUBLE,
     wdyear INT NOT NULL,
     CONSTRAINT pk_weekday PRIMARY KEY(wdname, wdyear)) ENGINE=InnoDB;

CREATE TABLE Flight
    (fnumber INT NOT NULL AUTO_INCREMENT,
     fweek INT,
     fwflight INT NOT NULL,
     CONSTRAINT pk_flight PRIMARY KEY(fnumber)) ENGINE=InnoDB;

CREATE TABLE Reservation
    (rnumber INT,
     rflight INT NOT NULL,
     rcontact INT,
     CONSTRAINT pk_reservation PRIMARY KEY(rnumber)) ENGINE=InnoDB;


CREATE TABLE Seat # Associates passengers with reservations
	(sreservation INT,
	 spassport INT,
     CONSTRAINT pk_seat PRIMARY KEY(sreservation, spassport)) ENGINE=InnoDB;

CREATE TABLE Passenger
    (ppassport INT,
     pname VARCHAR(30),
     CONSTRAINT pk_passenger PRIMARY KEY(ppassport)) ENGINE=InnoDB;

CREATE TABLE Ticket
    (tnumber INT,
     tbooking INT NOT NULL,
     tpassenger INT NOT NULL,
     CONSTRAINT pk_ticket PRIMARY KEY(tnumber)) ENGINE=InnoDB;

CREATE TABLE Contact
    (cpassengerid INT,
     cemail VARCHAR(30),
     cphone BIGINT,
     CONSTRAINT pk_contact PRIMARY KEY(cpassengerid)) ENGINE=InnoDB;

CREATE TABLE Booking # A booking correspond to a paid reservation
    (breservation INT,
     bprice DOUBLE,
     bpayer BIGINT NOT NULL,
     CONSTRAINT pk_booking PRIMARY KEY(breservation)) ENGINE=InnoDB;



CREATE TABLE CreditCard
    (ccnumber BIGINT,
    ccowner INT,
    CONSTRAINT pk_credit_card PRIMARY KEY(ccnumber)) ENGINE=InnoDB;


# Add all the foreign keys constraints
ALTER TABLE Route           ADD CONSTRAINT fk_route_rdeparture_airport   FOREIGN KEY (rdeparture_airport) REFERENCES Airport(acode);
ALTER TABLE Route           ADD CONSTRAINT fk_route_rarrival_airport     FOREIGN KEY (rarrival_airport)   REFERENCES Airport(acode);
ALTER TABLE Route           ADD CONSTRAINT fk_route_ryear                FOREIGN KEY (ryear)             REFERENCES Year(yyear);

ALTER TABLE WeeklyFlight    ADD CONSTRAINT fk_weeklyflight_wfyear         FOREIGN KEY (wfyear)            REFERENCES Year(yyear);
ALTER TABLE WeeklyFlight    ADD CONSTRAINT fk_weeklyflight_wfday            FOREIGN KEY (wfday)             REFERENCES WeekDay(wdname);
ALTER TABLE WeeklyFlight    ADD CONSTRAINT fk_weeklyflight_wfroute        FOREIGN KEY (wfrouteid)           REFERENCES Route(rid);

ALTER TABLE WeekDay         ADD CONSTRAINT fk_day_wdyear                  FOREIGN KEY (wdyear)            REFERENCES Year(yyear);
ALTER TABLE Flight          ADD CONSTRAINT fk_flight_wflight            FOREIGN KEY (fwflight)           REFERENCES WeeklyFlight(wfid);

ALTER TABLE Reservation     ADD CONSTRAINT fk_reservation_rflight        FOREIGN KEY (rflight)            REFERENCES Flight(fnumber);

ALTER TABLE Seat			ADD CONSTRAINT fk_seat_sreservation			 FOREIGN KEY (sreservation)		  REFERENCES Reservation(rnumber);
ALTER TABLE Seat			ADD CONSTRAINT fk_seat_spassport			 FOREIGN KEY (spassport)		  REFERENCES Passenger(ppassport);

ALTER TABLE Ticket          ADD CONSTRAINT fk_ticket_tpassenger          FOREIGN KEY (tpassenger)         REFERENCES Passenger(ppassport);
ALTER TABLE Ticket          ADD CONSTRAINT fk_ticket_tbooking            FOREIGN KEY (tbooking)           REFERENCES Booking(breservation);

ALTER TABLE Contact         ADD CONSTRAINT fk_contact_cpassengerid       FOREIGN KEY (cpassengerid)       REFERENCES Passenger(ppassport);

ALTER TABLE Booking         ADD CONSTRAINT fk_booking_breservation       FOREIGN KEY (breservation)       REFERENCES Reservation(rnumber);
ALTER TABLE Booking         ADD CONSTRAINT fk_booking_bpayer             FOREIGN KEY (bpayer)             REFERENCES CreditCard(ccnumber);
#ALTER TABLE Booking         ADD CONSTRAINT fk_booking_bcontact           FOREIGN KEY (bcontact)           REFERENCES Contact(cpassengerid);


delimiter //

# Add a new year with a given factor
CREATE PROCEDURE addYear(IN year INT, IN factor DOUBLE)
BEGIN
	INSERT INTO Year VALUES (year, factor);
END;
//

# Add a new Weekday for a given year and a given factor
CREATE PROCEDURE addDay(IN year INT, IN day VARCHAR(10), IN factor DOUBLE)
BEGIN
	INSERT INTO WeekDay VALUES (day, factor, year);
END;
//

# Add a new destination
CREATE PROCEDURE addDestination(IN airport_code VARCHAR(3), IN name VARCHAR(30), IN country VARCHAR(30))
BEGIN
	INSERT INTO Airport VALUES (airport_code, name, country);
END;
//

# Add a route between two destination for a given year with a given price
CREATE PROCEDURE addRoute(IN departure_airport_code VARCHAR(3), IN arrival_airport_code VARCHAR(30), IN year INT, IN routeprice DOUBLE)
BEGIN
	INSERT INTO Route (rdeparture_airport, rarrival_airport, rprice, ryear) VALUES (departure_airport_code, arrival_airport_code, routeprice, year);
END;
//

# Add a new WeeklyFlight entry and 52 correspondiogn flights
CREATE PROCEDURE addFlight(IN departure_airport_code VARCHAR(3), IN arrival_airport_code VARCHAR(30), IN year INT, IN day VARCHAR(10), IN departure_time TIME)
BEGIN
	DECLARE found_id INT; # The route id corresponding to the year and the two airports
	DECLARE count INT; # Counter for the loop
	SELECT rid INTO found_id FROM Route WHERE rdeparture_airport = departure_airport_code
										AND   rarrival_airport = arrival_airport_code
                                        AND   ryear = year;
    # Create a new WeeklyFlight
	INSERT INTO WeeklyFlight (wfdtime, wfday, wfyear, wfrouteid) VALUES (departure_time, day, year, found_id);

	SET count = 1;
	WHILE count <= 52 DO
		# Create a new flight connected to a WeeklyFlight
		INSERT INTO Flight (fweek, fwflight) VALUES
        (count, (SELECT wfid FROM WeeklyFlight WHERE wfdtime = departure_time
											   AND   wfday = day
                                               AND   wfyear = year
                                               AND   wfrouteid = found_id));
		SET count = count + 1;
	END WHILE;
END;
//

# Compute the number of free seats on a flight
CREATE FUNCTION calculateFreeSeats (flight_number INT)
RETURNS INT
BEGIN
	DECLARE n INT; # n will be the number of reserved seats
    # Count only the seats that have been paid, using the tickets
	SELECT COUNT(*) INTO n FROM Ticket WHERE tbooking IN (
		SELECT rnumber FROM Reservation WHERE rflight = flight_number
	);
	RETURN 40 - n; # 40 is the total number of seats in a plane
END;
//

# Compute the price of a seat for a given flight
CREATE FUNCTION calculatePrice (flight_number INT)
RETURNS DOUBLE
BEGIN
	DECLARE route_price DOUBLE;
	DECLARE weekday_factor DOUBLE;
	DECLARE free_seats INT;
	DECLARE profit DOUBLE;

	# Get the route price
	SELECT rprice INTO route_price FROM Route WHERE rid IN (
		SELECT wfrouteid FROM WeeklyFlight WHERE wfid IN (
			SELECT fwflight FROM Flight WHERE fnumber = flight_number
		)
	);

    # Get the weekday factor
	SELECT wdfactor INTO weekday_factor FROM WeekDay WHERE wdname IN (
		SELECT wfday FROM WeeklyFlight WHERE wfid IN (
			SELECT fwflight FROM Flight WHERE fnumber = flight_number
		)
	);

    # Get the number of free seats
	SELECT calculateFreeSeats(flight_number) INTO free_seats;

    # Get the year's profit_factor
	SELECT yprofit_factor INTO profit FROM Year WHERE yyear IN (
		SELECT wfyear FROM WeeklyFlight WHERE wfid IN (
			SELECT fwflight FROM Flight WHERE fnumber = flight_number
		)
	);

	# Compute the flight price using the gien formula
	RETURN ROUND(route_price * weekday_factor * (40 - free_seats + 1)/40 * profit, 5);
END;
//

# Trigger to generate ticketws
CREATE TRIGGER generateTickets
AFTER INSERT ON Booking # In our model we consider that a Booking is created only when the reservation is payed
FOR EACH ROW
BEGIN
	# Get the reservation number from the entry just added in Booking
	DECLARE reservation_number INT;
	SET reservation_number = NEW.breservation;

    # Create a ticket for each passeneger associated with the reservation
	INSERT INTO Ticket (tnumber, tbooking, tpassenger)
		SELECT rand()*2147483647, reservation_number, spassport FROM Seat WHERE sreservation = reservation_number;

END;
//

# Add a new reservation
CREATE PROCEDURE addReservation(IN departure_airport_code VARCHAR(3), IN arrival_airport_code VARCHAR(3), IN year INT, IN week INT, IN day VARCHAR(10), IN time TIME, IN number_of_passengers INT, OUT output_reservation_nr INT)
BEGIN
	DECLARE flight_number INT;
    DECLARE reservation_number INT;

    # Find the flight number corrsponding to the given informations
	SELECT fnumber INTO flight_number FROM Flight WHERE fweek = week AND fwflight IN (
		SELECT wfid FROM WeeklyFlight WHERE wfyear = year AND wfday = day AND wfdtime = time AND wfrouteid IN (
			SELECT rid FROM Route WHERE rarrival_airport = arrival_airport_code AND rdeparture_airport = departure_airport_code AND year = ryear
		)
	);

    IF flight_number IS NULL THEN
		SELECT 'There exist no flight for the given route, date and time' as 'Message';
	ELSE

		IF number_of_passengers > calculateFreeSeats(flight_number) THEN
			SELECT 'There are not enough seats available on the chosen flight' as 'Message';
		ELSE
			# Create a random reservation number, and create the reservation
			SET reservation_number = rand()*2147483647;
			INSERT INTO Reservation (rnumber, rflight) VALUES (reservation_number, flight_number);
			SELECT reservation_number INTO output_reservation_nr;
		END IF;
	END IF;


END;
//

# Add a passenger to a given reservation
CREATE PROCEDURE addPassenger(IN reservation_nr INT, IN passport_number INT, IN name VARCHAR(30))
BEGIN
	IF (SELECT rnumber FROM Reservation WHERE rnumber = reservation_nr) IS NULL THEN
		SELECT 'The given reservation number does not exist' AS 'Message';
	ELSE
		# Create the passenger itself and the connexion between the passeneger and the reservation
		INSERT INTO Passenger VALUES (passport_number, name);
        INSERT INTO Seat VALUES (reservation_nr, passport_number);
	END IF;

END;
//

# Add a contact in the database
CREATE PROCEDURE addContact(IN reservation_nr INT, IN passport_number INT, IN email VARCHAR(30), IN phone BIGINT)
BEGIN
	IF (SELECT rnumber FROM Reservation WHERE rnumber = reservation_nr) IS NULL THEN
		SELECT 'The given reservation number does not exist' AS 'Message';

	ELSE
		IF (SELECT spassport FROM Seat WHERE spassport = passport_number AND sreservation = reservation_nr) IS NULL THEN
			SELECT 'The person is not a passenger of the reservation' AS 'Message';
		ELSE
			INSERT INTO Contact VALUES (passport_number, email, phone);
            UPDATE Reservation SET rcontact = passport_number WHERE rnumber = reservation_nr;
		END IF;
    END IF;
END;
//

CREATE PROCEDURE addPayment(IN reservation_nr INT, IN cardholder_name VARCHAR(30), IN credit_card_number BIGINT)
BEGIN
	DECLARE contact INT;
    DECLARE nb_passengers INT;
    DECLARE flight INT;


	IF (SELECT rnumber FROM Reservation WHERE rnumber = reservation_nr) IS NULL THEN
		SELECT 'The given reservation number does not exist' AS 'Message';

	ELSE
		#SELECT cpassengerid INTO contact FROM Contact WHERE cpassengerid IN (SELECT spassport FROM Seat WHERE sreservation = reservation_nr);
        SELECT rcontact INTO contact FROM Reservation WHERE rnumber = reservation_nr;
        IF contact IS NULL THEN
			SELECT 'The reservation has no contact yet';
		ELSE
			# Count the number of passenger of the reservation
			SELECT COUNT(spassport) INTO nb_passengers FROM Seat WHERE sreservation = reservation_nr;

            # Get the flight number
            SELECT rflight INTO flight FROM Reservation WHERE rnumber = reservation_nr;

            # Check that there are enough unpaid seats on the flight
            IF (nb_passengers > calculateFreeSeats(flight)) THEN
				SET SQL_SAFE_UPDATES=0; # Needed if we want to be able to delete elements
				SELECT 'There is not enough seats left on the flight, removing reservation' AS 'Message';

                # Delete all traces for the reservation, but keep the people in the database for future use
                DELETE FROM Seat WHERE sreservation = reservation_nr;
                DELETE FROM Reservation WHERE rnumber = reservation_nr;
                SET SQL_SAFE_UPDATES=1;
            ELSE

                # Add a new Payment method (credit card with owner name)
				INSERT INTO CreditCard VALUES (credit_card_number, cardholder_name);

                # Add entry in the Booking table to save the payment, this will trigger the generation of the tickets
				INSERT INTO Booking (breservation, bprice, bpayer) VALUES (reservation_nr, (nb_passengers * calculatePrice(flight)), credit_card_number);

            END IF;

        END IF;
    END IF;
END;
//
delimiter ;


CREATE VIEW allFlights AS
SELECT  F.fweek AS 'departure_week', W.wfdtime AS 'departure_time', W.wfday AS 'departure_day',W.wfyear AS 'departure_year',
        A1.aname AS 'departure_city_name', A2.aname AS 'destination_city_name',
        calculateFreeSeats(F.fnumber) AS 'nr_of_free_seats', calculatePrice(F.fnumber) AS 'current_price_per_seat'
FROM Flight F, WeeklyFlight W, Route R, Airport A1, Airport A2
WHERE W.wfrouteid = R.rid AND F.fwflight = W.wfid AND A1.acode = R.rdeparture_airport AND A2.acode = R.rarrival_airport;
