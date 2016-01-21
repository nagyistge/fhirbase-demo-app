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

First helpful function is `fhir_create_storage('{"resourceType": "RESOURCE"}'::json);` which generates tables
for specific resources passed as array.
For example to generate tables for patient and organization:

```sql
SELECT fhir_create_storage('{"resourceType": "Patient"}'::json);
```

```sql
SELECT fhir_create_storage('{"resourceType": "Organization"}'::json);
```

## Public API functions

The first group of functions implements CRUD operations on resources:

* `fhir_create_resource(resource::jsonb)`
* `fhir_read_resource(resource::jsonb)`
* `fhir_update_resource(resource::jsonb)`
* `fhir_vread_resource(resource::jsonb)`
* `fhir_delete_resource(resource::jsonb)`
* `fhir_resource_history(resource::jsonb)`

Let's create first Patient with `fhir_create_resource`;
```sql
SELECT fhir_create_resource('{"resource": {"resourceType": "Patient", "name": [{"given": ["Smith"]}]}}');
```
When resource is created, `id` and `version_id` are generated as uuids.

Let's check if Patient was created:
```sql
SELECT resource_type, id, version_id, resource
 FROM patient
ORDER BY updated_at DESC
LIMIT 1
```

Now you can select last created patient's `id` and copy it for
all forthcoming requests:

```sql
SELECT id FROM patient ORDER BY updated_at DESC LIMIT 1
```

Also you can create resource with specific `id`:

```sql
SELECT fhir_create_resource('{
  "allowId": true, 
  "resource": {
    "resourceType": "Patient", 
    "id": "smith",
    "name":[{"given":"Bruno"}]}}');
```

Then rename it with `fhir_update_resource`:
```sql
SELECT fhir_update_resource('{
  "resource": {
    "resourceType": "Patient", 
    "id": "smith", 
    "name": [{"given": ["John"], 
              "family": ["Smith"]}]}}');
```

Repeat last update several times changing given name every time. 
Check how `patient_history` table grows.
Execute next query after every update and pay attention to `versions_count` 
number:

```sql
SELECT
 (SELECT count(*) FROM patient where id='smith' LIMIT 1 ) as patients_count,
 (SELECT count(*) FROM patient_history where id='smith' LIMIT 1) as versions_count
```

On each update, resource content is updated in the `patient` table, 
and old version of the resource is copied into the `patient_history` table.

`fhir_resource_history` will display all previous versions for any resource:

```sql
SELECT fhir_resource_history('{"resourceType": "Patient", "id": "smith"}');
```

Or get each change as single row:
```sql
SELECT json_array_elements(
  fhir_resource_history('{
    "resourceType": "Patient", 
    "id": "smith"
  }')::json->'entry');
```


However, returned `Bundle` resource may be too excess. Therefore, you can select any version
of `Patient` resource with `fhir_vread_resource`. Let's select one step before current
version:

```sql
-- read previous version of resource
SELECT fhir_vread_resource('{"resourceType": "Patient", "id": "smith", "versionId": "????"}');
```


It is time to delete the Patient but pay attention to the fact that we will
need last patient's `id`. 

Now go to the deletion:
```sql
SELECT fhir_delete_resource('{"resourceType": "Patient", "id": "smith"}');
-- should return last version
-- don't forget to copy "versionId" value.
```

## Search

Next part of API is a search API.
The following  functions will help you to search resources in FHIRbase:

* `fhir_search(resourceType, searchString)` - returns a bundle
* `fhir_explain_search(resourceType, searchString)` - shows an execution plan for search
* `fhir_search_sql(resourceType, searchString)` - shows the original sql query underlying the search

Now let's execute a search:

```sql
SELECT fhir_search('{"resourceType": "Patient", "queryString": "name=smith"}');
-- returns bundle
```

Behind the scenes, FHIRbase builds very smart and complex search SQL query. At 
some point you may need to debug it, or understand which indexes to set and
where. `fhir_search_sql` will decode a query for you. Let's try:

```sql
SELECT fhir_search_sql('{"resourceType": "Patient", "queryString": "name=smith"}');
-- see generated SQL
```

Now copy `fhir_search_sql` from result and run it:

```sql
SELECT patient.version_id, patient.logical_id, patient.resource_type,
patient.updated, patient.published, patient.category, patient.content FROM
patient WHERE (index_fns.index_as_string(patient.content, '{name,given}') ilike
'%mark%') LIMIT 100 OFFSET 0
```

Moreover, execution plan can be seen with `fhir_explain_search`. Try it:

```sql
-- explain query execution plan
SELECT fhir_explain_search('{"resourceType": "Patient", "queryString": "name=smith"}');
```

## Indexing

----------------------

Search works without indexing but search query would be slow
on any reasonable amount of data.
Therefore, FHIRbase has a group of indexing functions:

* `fhir_index_parameter(resourceType, searchParam)`
* `fhir_unindex_parameter(resourceType, searchParam)`

Indexes are not free - they eat space and slow inserts and updates.
That is why indexes are optional and completely under you control in FHIRbase.

Before indexing experiments, please keep in mind that searching time boost can be
observable only on thousands of entries. If you have enough patience, you can
go back to **Transaction** block and try to generate those thousands of
patients. After that, you'll see the difference sharp and clear.  

If you don't have that much patience - you'll get indexing functions
understanding and practice anyway. 


```sql
SELECT fhir_index_parameter('{"resourceType": "Patient", "name": "name"}');
```

```sql
SELECT fhir_unindex_parameter('{"resourceType": "Patient", "name": "name"}');
```
