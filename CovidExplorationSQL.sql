
select * from Covid_DA_1..CovidVaccinations order by 3,4;
select * from Covid_DA_1..CovidDeaths 
where continent IS NOT NULL --our data has locations as continents whereas it should be only countries
order by 3,4

--our focus data 
select location, 
	   date, 
	   total_cases, 
	   new_cases, 
	   total_deaths, 
	   population
from Covid_DA_1..CovidDeaths
order by 1,2


--Total cases VS Total deaths (Shows the likelihood of dying if affected by covid)
select location, 
	   date, 
	   total_cases, 
	   total_deaths, 
	   (CAST(total_deaths AS FLOAT) / CAST(total_cases AS FLOAT))*100 AS DeathPercentage
from Covid_DA_1..CovidDeaths
--where location like '%india%'
order by 1,2


--Total case VS Population (Shows what percentage of population is affected by Covid)
select location, 
       date, 
	   total_cases, 
	   population, 
	   (CAST(total_cases AS FLOAT) / CAST(population AS FLOAT))*100 AS AffectdPercentage
from Covid_DA_1..CovidDeaths
order by 1,2


--Highest infection rate acc to the population
select location, 
	   population, 
	   MAX(total_cases) as highestCases,
	   MAX((CAST(total_cases AS FLOAT) / CAST(population AS FLOAT))*100) AS AffectdPercentage
from Covid_DA_1..CovidDeaths
where continent IS NOT NULL
group by location, population
order by AffectdPercentage desc;


--Countries with the highest death count per population 
select location,
	   max(total_deaths) as highestDeath
from Covid_DA_1..CovidDeaths
where continent IS NOT NULL
group by location
order by highestDeath desc;


--Grouping by Continent
--Continent with the highest death count
select continent,
	   max(total_deaths) as highestDeath
from Covid_DA_1..CovidDeaths
where continent IS NOT NULL
group by continent
order by highestDeath desc;


--Global new cases 
select date, 
       sum(new_cases) as totalCases, 
       sum(new_deaths) as totalDeaths, 
	   sum(new_deaths)/sum(new_cases)*100 as deathPercentage
from Covid_DA_1..CovidDeaths
where continent is not null --to include conties alone 
group by date 
order by 1 desc


----Total case percentage of each country
SELECT location, SUM(CAST(COALESCE(new_cases, 0) AS BIGINT)) AS CumilativeTotalCases
FROM Covid_DA_1..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location
order by CumilativeTotalCases desc


--Country with highest death percentage
SELECT location, 
       MAX(total_deaths) AS TotalDeaths,
       MAX((CAST(total_deaths AS FLOAT) / CAST(total_cases AS FLOAT)) * 100) AS DeathRate
FROM Covid_DA_1..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY DeathRate DESC;


--Rank based on Case Fatality Rate (death vs cases)
SELECT location, 
       MAX(total_deaths) AS MaxTotalDeaths,
       (MAX(total_deaths) * 100.0 / NULLIF(MAX(total_cases), 0)) AS CFR
FROM Covid_DA_1..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY CFR DESC;


--Total Population VS Vaccination 
with vaccinated (Continent, Location, Date, Population, New_vaccinations, Cumilative_vacc_count)
as(
	select d.continent, 
		   d.location, 
		   d.date, 
		   d.population, 
		   v.new_vaccinations,
		   SUM(v.new_vaccinations) OVER (Partition by d.location order by d.location, d.date) as rolling_vaccinated_count
	from Covid_DA_1..CovidDeaths d
	join Covid_DA_1..CovidVaccinations v
	on d.location = v.location and d.date = v.date
	where d.continent is not null
)
select *, 
	  (CAST(Cumilative_vacc_count as float)/CAST(Population as float))*100 as vaccinatedPercentage
from vaccinated
order by Location;


--Country with highest vaccination rate 
SELECT d.location, 
       MAX(v.total_vaccinations) AS TotalVaccinated, 
       MAX(d.population) AS Population,
       (MAX(v.total_vaccinations) * 100.0 / MAX(d.population)) AS VaccinationRate
FROM Covid_DA_1..CovidDeaths d
JOIN Covid_DA_1..CovidVaccinations v 
ON d.location = v.location AND d.date = v.date
WHERE d.continent IS NOT NULL
GROUP BY d.location
ORDER BY VaccinationRate DESC;


--Population VS Cases VS Vaccination
SELECT d.location, 
       MAX(d.population) AS Population,
       MAX(d.total_cases) AS TotalCases,
       MAX(v.total_vaccinations) AS TotalVaccinations,
       (MAX(d.total_cases) * 100.0 / MAX(d.population)) AS CasePercentage,
       (MAX(v.total_vaccinations) * 100.0 / MAX(d.population)) AS VaccinationPercentage
FROM Covid_DA_1..CovidDeaths d
JOIN Covid_DA_1..CovidVaccinations v 
ON d.location = v.location AND d.date = v.date
WHERE d.continent IS NOT NULL
GROUP BY d.location
ORDER BY CasePercentage DESC;


--Case fatality rate with vaccination 
WITH DeathStats AS (
    SELECT location, 
           MAX(total_deaths) AS MaxTotalDeaths,
           MAX(total_cases) AS MaxTotalCases,
           (MAX(total_deaths) * 100.0 / NULLIF(MAX(total_cases), 0)) AS CFR
    FROM Covid_DA_1..CovidDeaths
    WHERE continent IS NOT NULL
    GROUP BY location
),
VaccinationStats AS (
    SELECT location, 
           MAX(people_fully_vaccinated) AS FullyVaccinated,
           MAX(total_vaccinations) AS TotalVaccinations
    FROM Covid_DA_1..CovidVaccinations
    GROUP BY location
)
SELECT d.location, 
       d.MaxTotalDeaths, 
       d.MaxTotalCases, 
       d.CFR, 
       v.FullyVaccinated, 
       v.TotalVaccinations
FROM DeathStats d
JOIN VaccinationStats v ON d.location = v.location
ORDER BY d.CFR DESC;


--Using a temp table
DROP Table if exists #PercentPopulationVaccinated
Create Table #PercentPopulationVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_vaccinations numeric,
RollingPeopleVaccinated numeric
)

Insert into #PercentPopulationVaccinated
Select d.continent, 
	   d.location, 
	   d.date, 
	   d.population, 
	   v.new_vaccinations, 
	   SUM(CONVERT(int,v.new_vaccinations)) OVER (Partition by d.Location Order by d.location, d.Date) as RollingPeopleVaccinated
From Covid_DA_1..CovidDeaths d
Join Covid_DA_1..CovidVaccinations v
	on d.location = v.location
	and d.date = v.date

Select *, 
	   (RollingPeopleVaccinated/Population)*100
From #PercentPopulationVaccinated


--View
Create View PercentPopulationVaccinated as
Select d.continent, 
	   d.location, 
	   d.date, 
	   d.population, 
	   v.new_vaccinations, 
	   SUM(CONVERT(int,v.new_vaccinations)) OVER (Partition by d.Location Order by d.location, d.Date) as RollingPeopleVaccinated
From Covid_DA_1..CovidDeaths d
Join Covid_DA_1..CovidVaccinations v
	on d.location = v.location
	and d.date = v.date
where d.continent is not null 

select * from PercentPopulationVaccinated
order by location


