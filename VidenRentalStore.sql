CREATE OR REPLACE PROCEDURE update_expiration_date 
(
  p_customer_id 		NUMBER,
  p_new_expiration_date 	DATE
)
AS
  v_count number;
BEGIN
  select count(1) into v_count 
  from customer where customer_id = p_customer_id;
  
  IF v_count != 1 THEN
    DBMS_OUTPUT.PUT_LINE('Invalid ID!');
  ELSE
    UPDATE Customer set EXPIRATION_DATE = p_new_expiration_date,
    LAST_UPDATE_DATE = sysdate where customer_id = p_customer_id;
    DBMS_OUTPUT.PUT_LINE('The expiration date has been updated.');
  END IF;
END;


CREATE OR REPLACE PROCEDURE video_search 
(
p_video_name 	VARCHAR2, 
p_video_format 	VARCHAR2 DEFAULT NULL
)
AS
cursor c_cursor is 
select video_name, video_copy.video_copy_id, format, copy_status,
case when copy_status ='R' then nvl(TO_CHAR(checkout_date),' ') else ' ' end checkout_date,
case when copy_status ='R' then nvl(TO_CHAR(due_date),' ') else ' ' end due_date
from video join video_copy on video.video_id = video_copy.VIDEO_ID
left outer join video_rental_record 
on video_copy.VIDEO_COPY_ID = video_rental_record.VIDEO_COPY_ID
where upper(video_name) like  '%'||UPPER(p_video_name)||'%'
and COPY_STATUS <> 'D'
and (
checkout_date is null or
checkout_date = (select max(checkout_date) from video_rental_record vrr where vrr.video_copy_id = video_rental_record.VIDEO_COPY_ID)
)
order by video_name, video_copy.video_copy_id;

v_result varchar(2048);
v_count_videos number;
v_count_avail_videos number;
BEGIN
  v_count_videos := 0;
  v_count_avail_videos := 0;
  v_result := '';
  FOR idx in c_cursor LOOP
    IF p_video_format is null or UPPER(idx.FORMAT) = UPPER(p_video_format) THEN
      v_result := v_result || idx.video_name || ' ' 
      || idx.video_copy_id || ' '
      || idx.format || ' '
      || idx.copy_status || ' '
      || idx.checkout_date || ' '
      || idx.due_date || chr(10);
      v_count_videos := v_count_videos + 1;
      IF (idx.copy_status = 'A') THEN
        v_count_avail_videos := v_count_avail_videos +1;
      END IF;
    END IF;
  END LOOP;
  
  DBMS_OUTPUT.PUT_LINE(v_count_videos);
  DBMS_OUTPUT.PUT_LINE(v_count_avail_videos);
  DBMS_OUTPUT.PUT_LINE(v_result);
END;


exec video_search('ANOTHER');



CREATE OR REPLACE PROCEDURE video_checkout
(	
  p_customer_id		NUMBER, 
	p_video_copy_id 		NUMBER, 
	p_video_checkout_date 	DATE 
)
as
  v_count number;
  v_expiration_date customer.expiration_date%TYPE;
  v_nb_days number;
  v_nb_of_copies_checkedout number;
begin
  select count(1) into v_count 
  from customer where customer_id = p_customer_id;
  
  IF v_count != 1 THEN
    DBMS_OUTPUT.PUT_LINE('The customer (id = ' || p_customer_id || ') is not in the customer table.');
    RETURN;
  END IF;
  
  select customer.expiration_date into v_expiration_date
  from customer where customer_id = p_customer_id;
  
  IF v_expiration_date < sysdate THEN
    DBMS_OUTPUT.PUT_LINE('The customer (id = ' || p_customer_id || ') is expired.');
    RETURN;
  END IF;
  
  select  count(1) into v_count 
  from video_copy where video_copy.video_copy_id = p_video_copy_id and
  video_copy.copy_status not in ('R', 'D');
  
  IF v_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('The video_copy (id = ' || p_video_copy_id || ') is NOT available.');
    RETURN;
  END IF;
  
  IF p_video_checkout_date > sysdate THEN
    DBMS_OUTPUT.PUT_LINE('The value of p_video_checkout_date is greater than the current date.');
    RETURN;
  END IF;
  
  select maximum_checkout_days into v_nb_days
  from video_copy join video on video.video_id = video_copy.video_id 
  where video_copy.video_copy_id = p_video_copy_id;
  
  select count(1) into v_nb_of_copies_checkedout
  from video_rental_record where customer_id = p_customer_id
  and return_date is null;
  
  IF v_nb_of_copies_checkedout >= 6 THEN
    DBMS_OUTPUT.PUT_LINE('The customer (id = ' || p_customer_id || ') has too many videos checked out.');
    RETURN;
  END IF;
  
  select count(1) into v_count from video_rental_record 
  where CUSTOMER_ID = p_customer_id and VIDEO_COPY_ID in
  (select video_copy_id from video_copy where video_id =
  (select video_copy.video_id from video join video_copy on video.video_id = video_copy.video_id 
  where video_copy_id = p_video_copy_id));
  
  IF v_count != 0 THEN
    DBMS_OUTPUT.PUT_LINE('The customer (id = ' || p_customer_id || ') is already renting this video.');
    RETURN;
  END IF;
  
  insert into video_rental_record values (p_customer_id, p_video_copy_id, sysdate, (sysdate + v_nb_days), NULL);
  
  update video_copy set copy_status = 'R' where video_copy_id = p_video_copy_id;
end;

exec video_checkout(124,1234,sysdate);

exec video_checkout(2008,1234,sysdate);

exec video_checkout(2002,1234,sysdate);

exec video_checkout(2002,6018,sysdate);

exec video_checkout(2002,6000,sysdate + 1);

exec video_checkout(2007,6003,sysdate);

exec video_checkout(2007,6020,sysdate);
exec video_checkout(2007,6015,sysdate);
exec video_checkout(2007,6014,sysdate);
exec video_checkout(2007,6013,sysdate);
exec video_checkout(2007,6012,sysdate);

select * from customer;

select * from video_copy where video_copy_id not in(
select video_copy_id  from video_rental_record
where return_date is null);

select * from video_rental_record
where return_date is null;



CREATE OR REPLACE PROCEDURE video_return
(
p_video_copy_id 		NUMBER, 
p_video_return_date 	DATE
)
AS
  v_count number;
BEGIN
  select  count(1) into v_count 
  from video_copy where video_copy.video_copy_id = p_video_copy_id;
  IF v_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('The video copy (id = ' || p_video_copy_id || ') is not in the video_copy table.');
    RETURN;
  END IF;
  
  select  count(1) into v_count 
  from video_copy where video_copy.video_copy_id = p_video_copy_id and
  video_copy.copy_status = 'R';
  IF v_count != 1 THEN
    DBMS_OUTPUT.PUT_LINE('The video copy (id = ' || p_video_copy_id || ') is not rented.');
    RETURN;
  END IF;
  
  IF p_video_return_date > sysdate THEN
    DBMS_OUTPUT.PUT_LINE('The return date is greater than the current date.');
    RETURN;
  END IF;
  
  update video_rental_record set return_date = p_video_return_date 
  where video_copy_id = p_video_copy_id and return_date is null;
  
  update video_copy set copy_status = 'A' where video_copy_id = p_video_copy_id;
END;


exec video_return(124,sysdate);

exec video_return(6000,sysdate);

exec video_return(6013,sysdate+3);

exec video_return(6013,sysdate);

select * from video_copy where video_copy_id not in(
select video_copy_id  from video_rental_record
where return_date is null);

select * from video_rental_record;

select * from video_copy;




CREATE OR REPLACE PROCEDURE print_unreturned_video
(
p_customer_id NUMBER
)
AS
  cursor c_cursor is 
  select CUSTOMER_ID, NAME, expiration_date from customer
  where CUSTOMER_ID = p_customer_id;
  
  cursor v_cursor is
  select video_rental_record.video_copy_id, video_name, format,
  checkout_date, due_date
  from video_rental_record join video_copy 
  on video_rental_record.video_copy_id = video_copy.video_copy_id 
  join video on video_copy.video_id = video.video_id
  where CUSTOMER_ID = p_customer_id
  and p_customer_id = customer_id and return_date is null
  order by due_date,video_name;
  
  v_first_checkout_date customer.expiration_date%TYPE;
  v_last_checkout_date customer.expiration_date%TYPE;
  v_count number;
BEGIN
  select count(1) into v_count 
  from customer where customer_id = p_customer_id;
  
  IF v_count != 1 THEN
    DBMS_OUTPUT.PUT_LINE('The customer (id = ' || p_customer_id || ') is not in the customer table.');
    RETURN;
  END IF;
  
  DBMS_OUTPUT.PUT_LINE(RPAD('-',70,'-'));
  for idx in c_cursor loop
    DBMS_OUTPUT.PUT_LINE(idx.CUSTOMER_ID);
    DBMS_OUTPUT.PUT_LINE(idx.name);
    DBMS_OUTPUT.PUT_LINE(idx.expiration_date);
  end loop;
  
  select min(checkout_date) into v_first_checkout_date
  from video_rental_record where CUSTOMER_ID = p_customer_id;
  
  select max(checkout_date) into v_last_checkout_date
  from video_rental_record where CUSTOMER_ID = p_customer_id;
  
  
  DBMS_OUTPUT.PUT_LINE(nvl(TO_CHAR(v_first_checkout_date),'N/A'));
  DBMS_OUTPUT.PUT_LINE(nvl(TO_CHAR(v_last_checkout_date),'N/A'));
  
  select count(1) into v_count from video_rental_record where CUSTOMER_ID = p_customer_id
  and p_customer_id = customer_id and return_date is null;
  
  DBMS_OUTPUT.PUT_LINE(RPAD('-',70,'-'));
  DBMS_OUTPUT.PUT_LINE('Number of Unreturned Videos: ' || v_count);
  DBMS_OUTPUT.PUT_LINE(RPAD('-',70,'-'));
  
  IF v_count > 0 THEN
    for idx in v_cursor loop
      DBMS_OUTPUT.PUT_LINE(idx.video_copy_id);
      DBMS_OUTPUT.PUT_LINE(idx.video_name);
      DBMS_OUTPUT.PUT_LINE(idx.format);
      DBMS_OUTPUT.PUT_LINE(idx.checkout_date);
      DBMS_OUTPUT.PUT_LINE(idx.due_date);
      DBMS_OUTPUT.PUT_LINE(RPAD('-',70,'-'));
    end loop;
  END IF;
END;

exec print_unreturned_video(90);
exec print_unreturned_video(2004);
exec print_unreturned_video(2008);
exec print_unreturned_video(2002);
  select * 
  from video_rental_record where CUSTOMER_ID = 2004;


CREATE OR REPLACE PACKAGE video_pkg AS
   PROCEDURE customer_registration
(	
	p_customer_id		NUMBER,
	p_password			VARCHAR2,	
	p_name 			VARCHAR2,
p_email_address 		VARCHAR2, 
p_phone_number 		VARCHAR2,
 	p_registration_date	DATE,
	p_expiration_date		DATE
);

PROCEDURE update_expiration_date 
(
p_customer_id 		NUMBER,
p_new_expiration_date 	DATE
);

PROCEDURE video_search 
(
p_video_name 	VARCHAR2, 
p_video_format 	VARCHAR2 DEFAULT NULL
);

PROCEDURE video_checkout
(	
p_customer_id		NUMBER, 
	p_video_copy_id 		NUMBER, 
	p_video_checkout_date 	DATE 
);

PROCEDURE video_return
(
p_video_copy_id 		NUMBER, 
p_video_return_date 	DATE
);

PROCEDURE print_unreturned_video
(
p_customer_id NUMBER
);

END video_pkg;
/