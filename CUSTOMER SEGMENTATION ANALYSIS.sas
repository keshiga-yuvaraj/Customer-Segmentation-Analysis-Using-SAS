PROC IMPORT DATAFILE= '/home/u63901349/online_retail.xlsx'
	DBMS=xlsx
	OUT=WORK.import
	REPLACE;
	RUN;
	
PROC PRINT DATA=work.import (OBS=10);

/* Handle Missing Values */

PROC MEANS DATA = WORK.IMPORT NMISS N;

/* Calculate Total Price for each transaction */
DATA WORK.IMPORT;
	SET WORK.IMPORT;
	TotalPrice = Quantity * UnitPrice;

/* PROC PRINT DATA=work.import (OBS=10); */

/* Aggregate data by CustomerID to get RFM (Recency, Frequency, Monetary) metrics */
PROC SQL;
	CREATE TABLE WORK.CUSTOMER_RFM AS
	SELECT CustomerID,
		MAX(InvoiceDate) AS LastPurchaseDate,
		COUNT(InvoiceNo) AS Frequency,
		SUM(TotalPrice) AS Monetary
	FROM WORK.IMPORT
	GROUP BY CustomerID;
QUIT;
/* 	Calculate Recency	 */

DATA WORK.CUSTOMER_RFM;
	SET WORK.CUSTOMER_RFM;
	Recency = '10dec2011'd - LastPurchaseDate;
/* Perform Clustering */

/* Standardize RFM metrics */

PROC STANDARD DATA= WORK.CUSTOMER_RFM OUT=WORK.standard_rfm MEAN=0 STD=1;
	VAR Recency Frequency Monetary;
RUN;

/* Determine the Number of Clusters */
PROC FASTCLUS DATA= WORK.standard_rfm MAXCLUSTERS= 4 OUT=WORK.clustered_customers;
	VAR Recency Frequency Monetary;
	
/*Analyzing and Interpreting the Clusters  */

/*Summarize the clusters  */
PROC MEANS DATA= WORK.clustered_customers;
	CLASS Cluster;
	VAR Recency Frequency Monetary;

/* scatter plots to visualize the clusters */
PROC SGPLOT DATA= WORK.clustered_customers;
	SCATTER X = Frequency Y = Monetary / GROUP= Cluster;
	TITLE 'Customer Segments by Frequency and Monetary';
	
PROC SGPLOT DATA= WORK.clustered_customers;
	SCATTER X = Recency Y = Monetary / GROUP= Cluster;
	TITLE 'Customer Segments by Recency and Monetary';
	
/*  RFM (Recency, Frequency, Monetary) analysis and visualize the distribution*/
PROC MEANS DATA=WORK.CUSTOMER_RFM NOPRINT;
	VAR Recency Frequency Monetary;
	OUTPUT OUT=WORK.rfm_stats MEAN= mean_receny mean_frequency mean_monetary;
	
PROC PRINT DATA= WORK.rfm_stats ;
	TITLE 'RFM Statistics';
	
/* Customer Lifetime Value (CLV) Analysis*/

DATA WORK.CUSTOMER_LTV;
	SET WORK.CUSTOMER_RFM;
	LTV = Frequency * Monetary;

PROC SGPLOT DATA=WORK.CUSTOMER_LTV;
	HISTOGRAM LTV;
	TITLE 'Distribution of Customer Lifetime Value';
	XAXIS LABEL= 'LTV';
	YAXIS LABEL= 'Frequency';

/* Market Basket Analysis */
/* To Identify frequent itemsets and association rules */
PROC FREQ DATA= WORK.IMPORT;
	TABLE Stockcode * Description / NOPRINT OUT= WORK.ITEM_PARIS;

PROC SQL;
	CREATE TABLE WORK.FREQUENT_ITEMSETS AS
	SELECT Stockcode, COUNT(*) AS Frequency
	FROM WORK.IMPORT 
	GROUP BY Stockcode
	HAVING COUNT(*) > 50;  /* Adjust threshold as needed */
QUIT;
	
PROC PRINT DATA= WORK.FREQUENT_ITEMSETS ;
	TITLE 'Frequent Itemsets';
	
/* Distribution of Transactions Over Time */
PROC SGPLOT DATA= WORK.IMPORT;
	SERIES X = InvoiceDate Y = TotalPrice / MARKERS;
	TITLE 'Total Sales Over Time';
	XAXIS LABEL= 'Date';
	YAXIS LABEL= 'Total Sales';
	
/* 	Distribution of Total Spending */
/* Inspect the Distribution */
PROC MEANS DATA= WORK.IMPORT N MEAN STD MAX MIN;
	VAR TotalPrice;

PROC UNIVARIATE DATA=WORK.IMPORT;
    VAR TotalPrice;
    HISTOGRAM TotalPrice / NORMAL;
    INSET N MEAN STD MIN MAX / POSITION=NE;

/* Log Transformation */
DATA WORK.IMPORT_LOG;
    SET WORK.IMPORT;
    IF TotalPrice > 0 THEN LogTotalPrice = LOG(TotalPrice);
/*     Filter Out Outliers  */

PROC SGPLOT DATA= WORK.IMPORT_LOG;
	HISTOGRAM LogTotalPrice / NBINS=50;
	TITLE 'Distribution of Log-Transformed Total Spending';
	XAXIS LABEL='Log(Total Price)';
	YAXIS LABEL= 'Frequency';

/* Distribution of Lifetime Value (LTV) */
DATA WORK.CUSTOMER_LTV_LOG;
    SET WORK.CUSTOMER_LTV;
    IF LTV > 0 THEN LogLTV = LOG(LTV);

/* Histogram of Log-Transformed LTV */

PROC SGPLOT DATA=WORK.CUSTOMER_LTV_LOG;
    HISTOGRAM LogLTV / NBINS=50;
    TITLE 'Distribution of Log-Transformed Customer Lifetime Value (LTV)';
    XAXIS LABEL='Log(Lifetime Value)';
    YAXIS LABEL='Frequency';
    
/* Scatter Plot of RFM Metrics */

PROC SGPLOT DATA=WORK.CUSTOMER_RFM;
    SCATTER X=Frequency Y=Monetary / GROUP=CustomerID;
    TITLE 'Scatter Plot of Frequency vs Monetary';
    XAXIS LABEL='Frequency';
    YAXIS LABEL='Monetary';

PROC SGPLOT DATA=WORK.CUSTOMER_RFM;
    SCATTER X=Recency Y=Monetary / GROUP=CustomerID;
    TITLE 'Scatter Plot of Recency vs Monetary';
    XAXIS LABEL='Recency';
    YAXIS LABEL='Monetary';


