
/********************************************************************************************

  License: This work is licensed under a Creative Commons Attribution-ShareAlike 3.0 Unported License.
  For more information: http://creativecommons.org/licenses/by-sa/3.0/deed.en_US
  Author(s): Jay Riddle 5/15/2013	

  Requirements:  PostgreSQL.  Tested on 9.2 (Untested on other databases)

  This script is written as an example for a lighting talk about query tuning.  We are using a 
  fairly simple version of the Sieve of Eratosthenes.  See: http://en.wikipedia.org/wiki/Sieve_of_Eratosthenes

  NOTE:  This demo may become outdated if future version of PostgreSQL handle query optimization differently.  

  Steps to Demo:

  1.  Review scripts to see how the prime number table is filled in.

  2.  Run the following select and notice that it should take about 3-5 seconds(Pre 2013 hardware).
      SELECT rebuild_prime_table();
      SELECT fill_primes(350000);

  3.  Run the following select and notice that it should much longer(unexpected result).  This should be somewhat conterintuitive. 
      SELECT rebuild_prime_table();
      analyze prime_numbers;
      SELECT fill_primes(350000);

   4. Run explain plan on the following and it should make sense now.
      Basically the query optimizer thinks the table is always small and so it skips using the index.
      
        INSERT INTO prime_numbers (p)
	SELECT 1234 
	WHERE NOT EXISTS
	  (
	  SELECT 1
	  FROM prime_numbers sieve
	  WHERE 1234 % sieve.p = 0	
	  AND sieve.p between 3 AND 36 -- We are only testing odd numbers so we can start at 3.
	  );

     5. Play. Remember to run rebuild_prime_table() between tests.  We have several options for fixing this issue.
    
        A. The cleanest is probably add the following into fill_primes(...) function.
        
		IF test_number = 2017 THEN
			ANALYZE prime_numbers;
		END IF;

	B. Run the batch partially:
	
		select fill_primes(5000);
		analyze prime_numbers;
		select fill_primes(350000);

	C. The _really_ evil fix:
	
		select evil_fake_stats(300);
		analyze prime_numbers;
		select fill_primes(350000);
		select remove_fake_stats();

*********************************************************************************************/


CREATE OR REPLACE FUNCTION rebuild_prime_table()
  RETURNS VOID AS
$$
DECLARE
BEGIN
  DROP table IF EXISTS prime_numbers;

  CREATE table prime_numbers (p bigint);

  CREATE UNIQUE INDEX prime_index_u1 ON prime_numbers(p);

  INSERT INTO prime_numbers(p) VALUES (2);
  INSERT INTO prime_numbers(p) VALUES (3);
  INSERT INTO prime_numbers(p) VALUES (5);
  INSERT INTO prime_numbers(p) VALUES (7);
  INSERT INTO prime_numbers(p) VALUES (11);
  INSERT INTO prime_numbers(p) VALUES (13);
  INSERT INTO prime_numbers(p) VALUES (17);

END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fill_primes(stop_point BIGINT)
  RETURNS BIGINT AS
$$
DECLARE
  DECLARE test_number BIGINT;
  DECLARE cal_square_root BIGINT;
BEGIN

  -- We are counting on the prime number table being pre-filled in with the first few primes
  --  We are starting with 17 so then 17+2 is 19. 
  SELECT MAX(p)+2 into test_number 
  FROM prime_numbers;
  
  WHILE test_number <= stop_point LOOP
	-- Cast appears to round appropriately for our prime test. Example: CAST(5.6 as bigint) is 6.
	cal_square_root := CAST(sqrt(test_number) as bigint); 
	
	INSERT INTO prime_numbers (p)
	SELECT test_number 
	WHERE NOT EXISTS
	  (
	  SELECT 1
	  FROM prime_numbers sieve
	  WHERE test_number % sieve.p = 0	
	  AND sieve.p between 3 AND cal_square_root -- We are only testing odd numbers so we can start at 3.
	  );

	test_number := test_number + 2;
  END LOOP;
  
  RETURN 1;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION evil_fake_stats(stop_point bigint)
  RETURNS bigint AS
$$
DECLARE
  DECLARE i BIGINT;
BEGIN

  FOR i IN 1..stop_point LOOP
	INSERT INTO prime_numbers (p) values (-i);
  END LOOP;

  analyze prime_numbers;
  
  RETURN 1;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION remove_fake_stats(stop_point bigint)
  RETURNS bigint AS
$$
DECLARE
  DECLARE i BIGINT;
BEGIN

  delete from prime_numbers where p < 2;
  
  RETURN 1;
END;
$$ LANGUAGE plpgsql;


	






