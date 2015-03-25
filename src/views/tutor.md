## Interactive Tutorial

We'll cover most important parts of FHIRbase in this tutorial.

Important note: this tutorial is interactive. This means 
you can run any code right on the page and get a feedback immediately.
Every time you see `Run` button, you can press it and the results of real
PostgreSQL query will be displayed at the bottom of the page inside of a "result"
popup block.

Let's try it now:

```sql
SELECT 'Run me, please';
```

However, you can always [install FHIRbase](http://fhirbase.github.io/installation.html) 
locally and repeat the same steps on your own machine. Just follow the 
[installation guide](http://fhirbase.github.io/installation.html).

Great, keep going further.

## FHIRbase Introduction

FHIRbase is a PostgreSQL extension for storing and retrieving
[FHIR resources](http://www.hl7.org/implement/standards/fhir/resources.html). You
can interact with FHIRbase using any PostgreSQL client. We advise you
to start with [pgAdmin](http://www.pgadmin.org/), because it has
easy-to-use graphical interface.  However, 
[other options](https://wiki.postgresql.org/wiki/Community_Guide_to_PostgreSQL_GUI_Tools)
are available.

[SQL](https://en.wikipedia.org/wiki/SQL) is the language in which you
"talk" to FHIRbase. If you don't have at least basic knowledge of SQL,
we strongly recommend to read some books or tutorials on the Web in the
first place.


## Functions as primary API

In SQL world, it's conventional to insert data with `INSERT` statement,
delete it with `DELETE`, update with `UPDATE` and so on. FHIRbase uses
less common approach - it forces you to use
[stored procedures](http://en.wikipedia.org/wiki/Stored_procedure) for
data manipulation. Reason for this is that FHIRbase needs to perform
additional actions on data changes in order to keep FHIR-specific
functionality (such as
[search](http://www.hl7.org/implement/standards/fhir/search.html) and
[versioning](http://www.hl7.org/implement/standards/fhir/http.html#vread))
working. In PostgreSQL world, stored procedures are called 
[functions](http://www.postgresql.org/docs/9.4/static/xfunc-sql.html). 
Hereinafter, we'll refer them as functions.

There are some exceptions from this rule in data retrieval cases. For
example, you can `SELECT ... FROM resource` to search for specific
resource or set of resources. However, when you create, delete or modify
something, you have to use corresponding function.

## Types

SQL has strict type checking, so function arguments and return values are
typed. When describing function, we will put type of every argument after two
colon(`::`) characters. For example, if argument `cfg` has `jsonb` type, 
we'll write:

* cfg::jsonb - Confguration data

You can look at the 
[overview of standard PostgreSQL types](http://www.postgresql.org/docs/9.4/static/datatype.html#DATATYPE-TABLE).

## JSON and XML

FHIR standard
[allows](http://www.hl7.org/implement/standards/fhir/formats.html) using two formats for data exchange: XML and JSON. They are
interchangeable, what means any XML representation of FHIR resource
can be unambiguously transformed into equivalent JSON
representation.

Considering interchangeability of XML and JSON FHIRbase team decided
to discard XML format support and use JSON as only format. There are
several advantages of such decision:

* PostgreSQL has native support for JSON data type which means fast
  queries and efficient storage;
* JSON is native and preferred format for Web Services/APIs nowadays;
* If you need an XML representation of a resource, you can always get
  it from JSON in your application's code.

## JSON parameter

When function argument has type `jsonb` that means you have to pass some
JSON as a value. To do this, you need to represent JSON as
single-line PostgreSQL string. You can do this in many ways, for
example, using an
[online JSON formatter](http://jsonviewer.stack.hu/). Copy-paste your
JSON into this tool, click "Remove white space" button and copy-paste
result back to editor.

Another thing we need to do before using JSON in SQL query is quote
escaping. Strings in PostgreSQL are enclosed in single quotes. Example:

```sql
SELECT 'this is a string';
```

If you have a single quote in your string, you have to **double** it:

```sql
SELECT 'I''m a string with a single quote!';
```

Therefore, if your JSON contains single quotes, Find and Replace them with two
single quotes in any text editor.

Finally, get your JSON, surround it with single quotes, and append
`::jsonb` after closing quote. That's how you pass JSON to PostgreSQL.

```sql
SELECT '{"foo": "i''m a string from JSON"}'::jsonb;
```

Sometimes you can omit `::jsonb` suffix and PostreSQL will parse it
automatically if your JSON representation is valid:

```sql
SELECT '{"foo": "i''m a string from JSON"}';
```

```sql
-- compare two JSONs, one of which built with ::jsonb
-- should return true
SELECT '{"foo": "bar"}'::jsonb @> '{"foo": "bar"}';
```

## FHIRbase Overview

**FHIRbase** is built on top of PostgreSQL and requires its version higher than 9.4
(i.e. [jsonb](http://www.postgresql.org/docs/9.4/static/datatype-json.html) support).

FHIR describes ~100 [resources](http://hl7-fhir.github.io/resourcelist.html)
as base StructureDefinitions, which by themselves are resources in FHIR terms.

FHIRbase stores each resource in two tables - one for current version
and second for previous versions of the resource. Following a convention, tables are named
in a lower case after resource types: `Patient` => `patient`,
`StructureDefinition` => `structuredefinition`.

For example, **Patient** resources are stored
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

Most of API for FHIRbase is represented as functions in `fhir` schema;
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

* `fhir.create(resource::jsonb)`
* `fhir.read(resource_type, logical_id)`
* `fhir.update(resource::jsonb)`
* `fhir.vread(resource_type, version_id)`
* `fhir.delete(resource_type, logical_id)`
* `fhir.history(resource_type, logical_id)`
* `fhir.is_exists(resource_type, logical_id)`
* `fhir.is_deleted(resource_type, logical_id)`

Let's create first Patient with `fhir.create`;
```sql
SELECT fhir.create('{"resourceType":"Patient", "name": [{"given": ["John"]}]}')
```
When resource is created, `logical_id` and `version_id` are generated as uuids.


Let's check if Patient was created:
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

Alternatively, you can use it directly in a query. Let's select last patient with `fhir.read`:

```sql
SELECT fhir.read('Patient',
  (SELECT logical_id FROM patient ORDER BY updated DESC LIMIT 1)
);
```

Then rename it with `fhir.update`:
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

Repeat last update several times changing given name every time. 
Check how `patient_history` table grows.
Execute next query after every update and pay attention to `versions_count` 
number:

```sql
SELECT
 (SELECT count(*) FROM patient LIMIT 1) as patients_count,
 (SELECT count(*) FROM patient_history LIMIT 1) as versions_count
```

On each update, resource content is updated in the `patient` table, 
and old version of the resource is copied into the `patient_history` table.

`fhir.history` will display all previous versions for any resource:

```sql
SELECT fhir.history('Patient', (SELECT logical_id FROM patient ORDER BY updated DESC LIMIT 1));
```

However, returned `Bundle` resource may be too excess. Therefore, you can select any version
of `Patient` resource with `fhir.vread`. Let's select one step before current
version:

```sql
-- read previous version of resource
SELECT fhir.vread('Patient', 
  (SELECT version_id FROM patient_history ORDER BY updated DESC LIMIT 1)
);
```

Now let's delete Patient. That deletion will take place in patient's history.
Let's use `is_exists` and `is_deleted` before any delete action.

```sql
SELECT fhir.is_exists('Patient', (SELECT logical_id FROM patient ORDER BY updated DESC LIMIT 1));
-- should return true
```

```sql
SELECT fhir.is_deleted('Patient', (SELECT logical_id FROM patient ORDER BY updated DESC LIMIT 1));
-- should return false
```

It is time to delete the Patient but pay attention to the fact that we will
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

For sure, you've already thought about creating multiple patients with one
query, or even about multiple different CRUD operations at the same time, like
`fhir.create`, `fhir.update`, `fhir.delete` and so on. Good news - FHIRbase has
solution for this, and it's called `fhir.transaction`.

Let's try it and create 10 patients with one transaction. However, transaction JSON
would become very long and hard to read without indent formatting. PostgreSQL
will not allow to pass multiline string easy way. So we'll use PostgreSQL 
[Dollar-Quoted String Constants](http://www.postgresql.org/docs/8.2/static/sql-syntax-lexical.html#SQL-SYNTAX-DOLLAR-QUOTING) 
and wrap long multiline JSON inside of paired `$$` tags. Short representation
of this idea: `fhir.transaction($$ HUGE_JSON $$)`.

Ok, run transaction now:

```sql
SELECT fhir.transaction($$ 
{
"resourceType":"Bundle",
"type":"transaction",
"entry": [
  {
    "transaction":{"method":"POST", "url":"/Patient"},
    "resource":{"resourceType":"Patient", "name":[{"given": ["Mark"]}]}
  },
  {
    "transaction":{"method":"POST", "url":"/Patient"},
    "resource":{"resourceType":"Patient", "name":[{"given": ["Boris"]}]}
  },
  {
    "transaction":{"method":"POST", "url":"/Patient"},
    "resource":{"resourceType":"Patient", "name":[{"given": ["Ted"]}]}
  },
  {
    "transaction":{"method":"POST", "url":"/Patient"},
    "resource":{"resourceType":"Patient", "name":[{"given": ["Mike"]}]}
  },
  {
    "transaction":{"method":"POST", "url":"/Patient"},
    "resource":{"resourceType":"Patient", "name":[{"given": ["Nick"]}]}
  },
  {
    "transaction":{"method":"POST", "url":"/Patient"},
    "resource":{"resourceType":"Patient", "name":[{"given": ["Chance"]}]}
  },
  {
    "transaction":{"method":"POST", "url":"/Patient"},
    "resource":{"resourceType":"Patient", "name":[{"given": ["Mary"]}]}
  },
  {
    "transaction":{"method":"POST", "url":"/Patient"},
    "resource":{"resourceType":"Patient", "name":[{"given": ["Cobe"]}]}
  },
  {
    "transaction":{"method":"POST", "url":"/Patient"},
    "resource":{"resourceType":"Patient", "name":[{"given": ["Paul"]}]}
  },
  {
    "transaction":{"method":"POST", "url":"/Patient"},
    "resource":{"resourceType":"Patient", "name":[{"given": ["Daniel"]}]}
  }]
} 
$$)
```

Let's check if patients were created:
```sql
SELECT resource_type, logical_id, version_id, content
FROM patient
ORDER BY updated DESC
LIMIT 10
```

## Search

Next part of API is a search API.
The following  functions will help you to search resources in FHIRbase:

* `fhir.search(resourceType, searchString)` - returns a bundle
* `fhir._search(resourceType, searchString)` - returns a relation
* `fhir.explain_search(resourceType, searchString)` - shows an execution plan for search
* `fhir.search_sql(resourceType, searchString)` - shows the original sql query underlying the search

You can repeat patient creation with `fhir.transaction` multiple times to
populate FHIRbase data a little.

Now let's execute a search:

```sql
select fhir.search('Patient', 'given=mark')
-- returns bundle
```

`Bundle` JSON can be not very convenient form for result and you may want to see
every patient in a single row, that's why `fhir._search` is needed.

Let's search and get one patient per row:

```sql
select * from fhir._search('Patient', 'name=mark&count=10');
-- returns search as relation
-- pay attention to logical_id fields, they must be different
```

Behind the scenes, FHIRbase builds very smart and complex search SQL query. At 
some point you may need to debug it, or understand which indexes to set and
where. `fhir.search_sql` will decode a query for you. Let's try:

```sql
select fhir.search_sql('Patient', 'given=mark&count=10');

-- SELECT * FROM patient
-- WHERE (index_fns.index_as_string(patient.content, '{given}') ilike '%david%')
-- LIMIT 10
-- OFFSET 0
```

Now copy `search_sql` from result, run it separately and compare to previous
`fhir._search` results:

```sql
SELECT patient.version_id, patient.logical_id, patient.resource_type,
patient.updated, patient.published, patient.category, patient.content FROM
patient WHERE (index_fns.index_as_string(patient.content, '{name,given}') ilike
'%mark%') LIMIT 100 OFFSET 0
-- Look, it completely identical to 
-- select * from fhir._search('Patient', 'name=mark&count=10');
```

Moreover, execution plan can be seen with `fhir.explain_search`. Try it:

```sql
-- explain query execution plan
select fhir.explain_search('Patient', 'given=mark&count=10');
```

## Indexing

Search works without indexing but search query would be slow
on any reasonable amount of data.
Therefore, FHIRbase has a group of indexing functions:

* `index_search_param(resourceType, searchParam)`
* `drop_index_search_param(resourceType, searchParam)`
* `index_resource(resourceType)`
* `drop_resource_indexes(resourceType)`
* `index_all_resources()`
* `drop_all_resource_indexes()`

Indexes are not free - they eat space and slow inserts and updates.
That is why indexes are optional and completely under you control in FHIRbase.

Before indexing experiments, please keep in mind that searching time boost can be
observable only on thousands of entries. If you have enough patience, you can
go back to **Transaction** block and try to generate those thousands of
patients. After that, you'll see the difference sharp and clear.  

If you don't have that much patience - you'll get indexing functions
understanding and practice anyway. 

Well, let's go. First, drop all existing indexes 
for `Patient` resource with `drop_resource_indexes`:

```sql
SELECT fhir.drop_resource_indexes('Patient');
```

Check if `Patient` names index exists. Next query should return empty
result:

```sql
-- Patient names index size
select * from (select obj->>'relname' as relname, obj->>'size' as size
from jsonb_array_elements(fhir.admin_disk_usage_top(100)) as obj) x
where relname = 'public.patient_name_name_string_idx'
```

Check how many patients you have now:

```
SELECT COUNT(*) from patient;
```

Then follow up to indexing. Most important function for that is 
`fhir.index_search_param` which accepts resourceType as a first parameter, and 
name of search parameter to index.

Let's check request timing for search without index you have already ran before. 
You can see execution time in the header of result popup, near **result** word. 
Make search request multiple times and remember average execution time value:

```sql
-- search without index
SELECT fhir.search('Patient', 'given=mark&count=10');
```

Next step - add index for `Patient` names with `fhir.index_search_param`:

```sql
-- index search param
SELECT fhir.index_search_param('Patient','name');
```

Check if index was created. The query should return the size of just created
`Patient` names index:

```sql
-- Patient names index size
select * from (select obj->>'relname' as relname, obj->>'size' as size
from jsonb_array_elements(fhir.admin_disk_usage_top(100)) as obj) x
where relname = 'public.patient_name_name_string_idx'
```

Repeat patient search multiple times again and compare average execution timing 
value now. You'll see a huge performance impact on a large number of patients:

```sql
-- search with index
SELECT fhir.search('Patient', 'given=mark&count=10');
```

For more understanding, you can research query execution plan. This time you
can see **Bitmap Index Scan** string in results.

```sql
-- explain search
select fhir.explain_search('Patient', 'name=mark&count=10');
```

Try to run `fhir.drop_resource_indexes` and 
`fhir.index_search_param('Patient','name')` multiple times and check the result
of `fhir.explain_search` every time.

