# VideoRentalStoreDatabase
PL/SQL-base application to insert and update records in a video rental store database, and generate some reports.


The database consists of only the following essential tables.

•	CUSTOMER(CUSTOMER_ID, PASSWORD, NAME, EMAIL_ADDRESS, PHONE_NUMBER,
   	   REGISTRATION_DATE, EXPIRATION_DATE, LAST_UPDATE_DATE);

•	VIDEO(VIDEO_ID, VIDEO_NAME, FORMAT, PUBLISH_DATE,
   MAXIMUM_CHECKOUT_DAYS);

•	VIDEO_COPY(VIDEO_COPY_ID, VIDEO_ID*, COPY_STATUS);

•	VIDEO_RENTAL_RECORD(CUSTOMER_ID*, VIDEO_COPY_ID*, CHECKOUT_DATE,
   DUE_DATE, RETURN_DATE);

The primary keys are marked in red and the foreign keys are marked with asterisks.

VIDEO_COPY(COPY_STATUS): 	A – Available, R – Rented, D – Damaged

Each video in the VIDEO table has at least one video copy in the VIDEO_COPY table.
