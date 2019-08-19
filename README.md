# Power BI
 Code related to power bi

Currently includes powershell script and power bi report to extract Power BI activity from audit log in office 365 tenant and analyse that data in a Power BI report. 

This allows analysis on users producing their own reports and activites on the PBI online. My client has rolled out self-service analytics and I'm keen to gauge the success of the project by analysing the production and consumption of reports. I can also collect evidence of how they're navigating the online service if they're working to best practices, if not I can give them tips.

I have the powershell script currently set up to export the data to an SQL server database but can also export to a CSV. This report uses example data I've manually edited in a CSV file with a few users with some considerations of the analysis of the report. I.e. one user has produced the same report as another and only keeps it in her personal online storage, therefore efforts are duplicated unnecessarily. 
