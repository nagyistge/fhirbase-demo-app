# FHIRBase Introduction

We assume that you have successfully
[installed FHIRBase](http://fhirbase.github.io/installation.html)
 and already configured connection parameters in your
PostgreSQL client.  Or you able to follow this tutorial in more
convinient way and run any code right on this page, cause it is interactive.
Every time you see `Run` button, you can press it and the results of real
PostgreSQL query will be shown in the bottom part of a page, inside of "result"
popup block.

FHIRBase is a PostgreSQL extension for storing and retrieving
[FHIR resources](http://www.hl7.org/implement/standards/fhir/resources.html). You
can interact with FHIRBase using any PostgreSQL client. We advise you
to start with [pgAdmin](http://www.pgadmin.org/), because it has
easy-to-use graphical interface.  However, 
[other options](https://wiki.postgresql.org/wiki/Community_Guide_to_PostgreSQL_GUI_Tools)
are available.

[SQL](https://en.wikipedia.org/wiki/SQL) is the language in which you
"talk" to FHIRBase. If you don't have at least basic knowledge of SQL,
we strongly advise to read some books or tutorials on the Web in the
first place.


## Stored Procedures as primary API

In SQL world it's conventional to insert data with `INSERT` statement,
delete it with `DELETE`, update with `UPDATE` and so on. FHIRBase uses
less common approach - it forces you to use
[stored procedures](http://en.wikipedia.org/wiki/Stored_procedure) for
data manipulation. Reason for this is that FHIRBase needs to perform
additional actions on data changes in order to keep FHIR-specific
functionality (such as
[search](http://www.hl7.org/implement/standards/fhir/search.html) and
[versioning](http://www.hl7.org/implement/standards/fhir/http.html#vread))
working.

There are some exceptions from this rule in data retrieval cases. For
example you can `SELECT ... FROM resource` to search for specific
resource or set of resources. But when you create, delete or modify
something, you have to use corresponding stored procedures
(hereinafter, we'll refer them as SP).

## Types

SQL has strict type checking, so SP's arguments and return values are
typed. When describing SP, we will put type of every argument after two
colon(`::`) characters. For example, if argument `cfg` has `jsonb` type, 
we'll write:

* cfg::jsonb - Confguration data

You can take a look at
[overview of standard PostgreSQL types](http://www.postgresql.org/docs/9.4/static/datatype.html#DATATYPE-TABLE).

## JSON and XML

FHIR standard
[allows](http://www.hl7.org/implement/standards/fhir/formats.html) to
use two formats for data exchange: XML and JSON. They are
interchangeable, what means any XML representation of FHIR resource
can be unambiguously transformed into equivalent JSON
representation.

Considering interchangeability of XML and JSON FHIRBase team decided
to discard XML format support and use JSON as only format. There are
several advantages of such decision:

* PostgreSQL has native support for JSON data type which means fast
  queries and efficient storage;
* JSON is native and preferred format for Web Services/APIs nowadays;
* If you need an XML representation of a resource, you can always get
  it from JSON in your application's code.

## Passing JSON to a Stored Procedure

When SP's argument has type `jsonb`, that means you have to pass some
JSON as a value. To do this, you need to represent JSON as
single-line PostgreSQL string. You can do this in many ways, for
example, using a
[online JSON formatter](http://jsonviewer.stack.hu/). Copy-paste your
JSON into this tool, click "Remove white space" button and copy-paste
result back to editor.

Another thing we need to do before using JSON in SQL query is quote
escaping. Strings in PostgreSQL are enclosed in single quotes. Example:

```sql
SELECT 'this is a string';
```

If you have single quote in your string, you have to **double** it:

```sql
SELECT 'I''m a string with single quote!';
```

So if your JSON contains single quotes, Find and Replace them with two
single quotes in any text editor.

Finally, get your JSON, surround it with single quotes, and append
`::jsonb` after closing quote. That's how you pass JSON to PostgreSQL.

```sql
SELECT '{"foo": "i''m a string from JSON"}'::jsonb;
```

Sometimes you can omit `::jsonb` suffix and PostreSQL will parse it
automaticly, if your JSON representation is valid:

```sql
SELECT '{"foo": "i''m a string from JSON"}';
```

```sql
-- compare two JSONs, one of which built with ::jsonb
-- should return true
SELECT '{"foo": "bar"}'::jsonb @> '{"foo": "bar"}';
```
# FHIRbase: FHIR persistence in PostgreSQL

FHIR is a specification of semantic resources and API for working with healthcare data.
Please address the [official specification](http://hl7-fhir.github.io/) for more details.

To implement FHIR server we have to persist & query data in an application internal
format or in FHIR format. This article describes how to store FHIR resources
in a relational database (PostgreSQL), and open source FHIR
storage implementation - [FHIRbase](https://github.com/fhirbase/fhirbase).


## Overview

**FHIRbase** is built on top of PostgreSQL and requires its version higher than 9.4
(i.e. [jsonb](http://www.postgresql.org/docs/9.4/static/datatype-json.html) support).

FHIR describes ~100 [resources](http://hl7-fhir.github.io/resourcelist.html)
as base StructureDefinitions which by themselves are resources in FHIR terms.

FHIRbase stores each resource in two tables - one for current version
and second for previous versions of the resource. Following a convention, tables are named
in a lower case after resource types: `Patient => patient`,
`StructureDefinition => structuredefinition`.

For example **Patient** resources are stored
in `patient` and `patient_history` tables:

```sql
-- show Patient table schema
select column_name, data_type
from information_schema.columns where
table_name='patient';
```

```sql
-- show Patient history table schema
select column_name, data_type
from information_schema.columns where
table_name='patient_history';
```

All resource tables have similar structure and are inherited from `resource` table,
to allow cross-table queries (for more information see [PostgreSQL inheritance](http://www.postgresql.org/docs/9.4/static/tutorial-inheritance.html)).

Minimal installation of FHIRbase consists of only a
few tables for "meta" resources:

* StructureDefinition
* OperationDefinition
* SearchParameter
* ValueSet
* ConceptMap

These tables are populated with resources provided by FHIR distribution.

Most of API for FHIRbase is represented as functions in `fhir` schema,
other schemas are used as code library modules.

First helpful function is `fhir.generate_tables(resources::text[])` which generates tables
for specific resources passed as array.
For example to generate tables for patient, organization and encounter:

```sql
select fhir.generate_tables('{Patient, Organization, Encounter}');
```

If you call `generate_tables()` without any parameters,
then tables for all resources described in `StructureDefinition`
will be generated:

```sql
select fhir.generate_tables();
```

When concrete resource type tables are generated,
column `installed` for this resource is set to true in the profile table.

```sql
-- show column 'installed' for Patient table
SELECT logical_id, installed from structuredefinition
WHERE logical_id = 'Patient'
```

## Public API functions

Functions representing public API of FHIRbase are all located in the `fhir` schema.
The first group of functions implements CRUD operations on resources:

* create(resource::jsonb)
* read(resource_type, logical_id)
* update(resource::jsonb)
* vread(resource_type, version_id)
* delete(resource_type, logical_id)
* history(resource_type, logical_id)
* is_exists(resource_type, logical_id)
* is_deleted(resource_type, logical_id)


Let's create first Patient with `fhir.create`;
```sql
SELECT fhir.create('{"resourceType":"Patient", "name": [{"given": ["John"]}]}')
```
When resource is created, `logical_id` and `version_id` are generated as uuids.


Let's check, if Patient was created:
```sql
SELECT resource_type, logical_id, version_id, content
 FROM patient
ORDER BY updated DESC
LIMIT 2
```

Now you can select last created patient's `logical_id` and copy it for
all forthcoming requests:

```sql
(SELECT logical_id FROM patient ORDER BY updated DESC LIMIT 1)
```

Or you can use it in request directly. Let's select last patient with `fhir.read`:

```sql
SELECT fhir.read('Patient',
  (SELECT logical_id FROM patient ORDER BY updated DESC LIMIT 1)
);
```

And rename it with `fhir.update`:
```sql
SELECT fhir.update(
   jsonbext.merge(
     fhir.read('Patient',
       (SELECT logical_id FROM patient ORDER BY updated DESC LIMIT 1)
     ),
     '{"name":[{"given":"Bruno"}]}'
   )
);
-- returns updated version
--
-- Did you noticed that patient named Bruno now?
-- Forget to mention, that you can edit any text inside of this code block.
-- Try to rename {"given":"Bruno"} to any name you want and run code multiple times
```

Repeat last update several times, but change given name every time. 
Check how `patient_history` table grows.
Execute next query after every update and pay attention to `versions_count` 
number:

```sql
SELECT
 (SELECT count(*) FROM patient LIMIT 1) as patients_count,
 (SELECT count(*) FROM patient_history LIMIT 1) as versions_count
```

On each update resource content is updated in the `patient` table, 
and old version of the resource is copied into the `patient_history` table.

`fhir.history` will show all previous versions for any resource:

```sql
SELECT fhir.history('Patient', (SELECT logical_id FROM patient ORDER BY updated DESC LIMIT 1));
```

But returned `Bundle` resource may be too excess. So you can select any version
of `Patient` resource with `fhir.vread`. Let's select one step before current
version:

```sql
-- read previous version of resource
SELECT fhir.vread('Patient', 
  (SELECT version_id FROM patient_history ORDER BY updated DESC LIMIT 1)
);
```

Now let's delete Patient. That deletion will take place in patient's history.
But let's use `is_exists` and `is_deleted` before any delete action.

```sql
SELECT fhir.is_exists('Patient', (SELECT logical_id FROM patient ORDER BY updated DESC LIMIT 1));
-- should return true
```

```sql
SELECT fhir.is_deleted('Patient', (SELECT logical_id FROM patient ORDER BY updated DESC LIMIT 1));
-- should return false
```

Time to delete the Patient, but pay attention to the fact, that we'll
need last patient's `logical_id` for the final **is_exists** and **is_deleted**
checks. `fhir.delete` will return that `logical_id` and you need to copy and paste it
further.

Now go to the deletion:
```sql
SELECT fhir.delete('Patient', (SELECT logical_id FROM patient ORDER BY updated DESC LIMIT 1));
-- should return last version
-- don't forget to copy "versionId" value.
```

```sql
SELECT fhir.is_exists('Patient', 'replace-this-to-copied-logical-id');
-- should return false
```

```sql
SELECT fhir.is_deleted('Patient', 'replace-this-to-copied-logical-id');
-- should return true
```

## Transaction


## Search & Indexing

Next part of API is a search API.
Folowing functions will help you to search resources in FHIRbase:

* fhir.search(resourceType, searchString) returns a bundle
* fhir._search(resourceType, searchString) returns a relation
* fhir.explain_search(resourceType, searchString) shows an execution plan for search
* fhir.search_sql(resourceType, searchString) shows the original sql query underlying the search

```sql

select fhir.search('Patient', 'given=john')
-- returns bundle
-- {"type": "search", "entry": [...]}
```

```sql
select * from fhir._search('Patient', 'name=david&count=10');
-- returns search as relatio

-- version_id | logical_id     | resource_type
------------+----------------------------------
--            | "a8bec52c-..." | Patient
--            | "fad90884-..." | Patient
--            | "895fdb15-..." | Patient
```

```sql
-- expect generated by search sql
select fhir.search_sql('Patient', 'given=david&count=10');

-- SELECT * FROM patient
-- WHERE (index_fns.index_as_string(patient.content, '{given}') ilike '%david%')
-- LIMIT 100
-- OFFSET 0
```

```sql
-- explain query execution plan
select fhir.explain_search('Patient', 'given=david&count=10');

-- Limit  (cost=0.00..19719.37 rows=100 width=461) (actual time=6.012..7198.325 rows=100 loops=1)
--   ->  Seq Scan on patient  (cost=0.00..81441.00 rows=413 width=461) (actual time=6.010..7198.290 rows=100 loops=1)
--         Filter: (index_fns.index_as_string(content, '{name,given}'::text[]) ~~* '%david%'::text)
--         Rows Removed by Filter: 139409
-- Planning time: 0.311 ms
-- Execution time: 7198.355 ms
```

Search works without indexing but search query would be slow
on any reasonable amount of data.
So FHIRbase has a group of indexing functions:

* index_search_param(resourceType, searchParam)
* drop_index_search_param(resourceType, searchParam)
* index_resource(resourceType)
* drop_resource_indexes(resourceType)
* index_all_resources()
* drop_all_resource_indexes()

Indexes are not for free - they eat space and slow inserts and updates.
That is why indexes are optional and completely under you control in FHIRbase.

Most important function is `fhir.index_search_param` which
accepts resourceType as a first parameter, and name of search parameter to index.

```sql
select count(*) from patient;
-- returns total number of patients
```

```sql
-- search without index
select fhir.search('Patient', 'given=david&count=10');
-- Time: 7332.451 ms
```

```sql
-- index search param
SELECT fhir.index_search_param('Patient','name');
--- Time: 15669.056 ms
```

```sql
-- index cost
select fhir.admin_disk_usage_top(10);
-- [
--  {"size": "107 MB", "relname": "public.patient"},
--  {"size": "19 MB", "relname": "public.patient_name_name_string_idx"},
--  ...
-- ]
```

```sql
-- search with index
select fhir.search('Patient', 'name=david&count=10');
-- Time: 26.910 ms
```

```sql
-- explain search

select fhir.explain_search('Patient', 'name=david&count=10');

------------------------------------------------------------------------------------------------------------------------------------------------
-- Limit  (cost=43.45..412.96 rows=100 width=461) (actual time=0.906..6.871 rows=100 loops=1)
--   ->  Bitmap Heap Scan on patient  (cost=43.45..1569.53 rows=413 width=461) (actual time=0.905..6.859 rows=100 loops=1)
--         Recheck Cond: (index_fns.index_as_string(content, '{name}'::text[]) ~~* '%david%'::text)
--         Heap Blocks: exact=100
--         ->  Bitmap Index Scan on patient_name_name_string_idx  (cost=0.00..43.35 rows=413 width=0) (actual time=0.205..0.205 rows=390 loops=1)
--               Index Cond: (index_fns.index_as_string(content, '{name}'::text[]) ~~* '%david%'::text)
-- Planning time: 0.449 ms
-- Execution time: 6.946 ms
```

### Performance Tests

### Road Map



