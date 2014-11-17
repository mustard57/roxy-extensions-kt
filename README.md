# Roxy Extensions

This archive provides extensions to Roxy. They fall into three categories

1.  Automated setup of failover
2.  Automated setup of database replication
3.  Other

**Installation**: tar xvf this archive. Then cp -R the contents into your project. Probably best to back your project up first.

To see a full list of commands, then `do ml local help`. A list is also given below under the heading 'Extension Command List'.

## Automated Setup of Failover

In large deployments, setup of failover forests is time consuming and error prone. Most people I am sure end up writing custome scripts to aid this. However, this is clearly ineffecient, and correct placement does require a little thought. These tasks aid this process.

They are

```
create_application_replica_forests  Creates replica forests for the application database
delete_application_replica_forests  Removes replica forests for the application database
# create_system_replica_forests Creates replica forests for the system databases
# delete_system_replica_forests Removes replica forests for the system databases
```

The required configuration is insertion of

```
replica-forest-directory=/directory-path-1,/directory-path-2,....
```

into your properties file. The number of paths indicates the level of replication - one path - 1x replication, two paths - 2x and so on. An example is in example.properties in this bundle.

The script places using a round robin algorithm i.e. in an n host cluster, the replica forests for host 1 are placed one on host2, one on host 3 ... one on host n, one on host 2 until the number of forests to be replicated for host 1 is reached. The placement for host2 is the same, but placement starts at host3. This algorithm ensures that in the event of a single host failure, the extra load is distributed across the cluster, rather than falling onto just one host. Note that your modules database forests also have failover assets created.

* The command `create_system_replica_forests` creates failover forests for the App-Services, Security, Schema and Triggers databases - which is required for a fully resilient system. They also use the replica-forest-directory parameter.
* The commands `delete_application_replica_forests` and `delete_system_replica_forests` reverse the above process.

You're probably best replicating App-Services/Security/Schemas by hand for the time being. Adding replica forests takes the databases concerned offline, and for Security and Schemas that means the transaction will be terminated. Comment in/out the databases you want replicated in app_specific.rb.

This bundle also supports `ml env restart_failed_forests` which will restore master forests to master status, in the event of failover having occurred. Note this will not otherwise happen automatically.

## Database Replication

As Roxy names forests by including the host name into the forest name you cannot join by name if setting up replication between two clusters that have been set up using Roxy.

The commands below solve this problem, and also provide a convenient push button tool for this type of setup.

To use you need to identify your remote host - do this by adding

```
dr-host=backup.mydomain.com
dr-admin-password=mypassword
```

to your properties file. An example is given in example.properties.

You can then run

```sh
ml env couple_clusters    # ( to couple the clusters )
ml env replicate_database # ( to replicate your content database )
```

You can also run

```sh
ml env remove_database_replication
ml env decouple_clusters
```

to reverse this process - which is useful if trying to enable DR. Note that having set up against production for example, you can run `remove_database_replication` and `decouple_clusters` vs DR even if Production is not available. You can also run `ml dr couple_clusters`, `ml dr replicate_database` to *reverse* the direction of replication - in your dr properties file you must name the former 'production' as dr.

### This bundle also supports

`ml env rollback_incomplete_transaction` - which will roll back to the non-blocking timestamp - a required action when switching to dr - requiring careful scripting if this process were not being used.

## Other

This bundle supports `ml env execute_setup_scripts`.

This will run names scripts vs your xcc server.

To use this add:

```
setup-scripts=script-1-path,script-2-path
```

to your properties file. Relative paths are relative to the root roxy directory.


## Extension Command List

| command                              | action                                                              |
| :----------------------------------- | :------------------------------------------------------------------ |
| `create_application_replica_forests` | Creates replica forests for the application database                |
| `delete_application_replica_forests` | Removes replica forests for the application database                |
| `create_system_replica_forests`      | Creates replica forests for the system databases                    |
| `delete_system_replica_forests`      | Removes replica forests for the system databases                    |
| `couple_clusters`                    | Couple to a remote cluster                                          |
| `decouple_clusters`                  | Remove remote coupling                                              |
| `replicate_database`                 | Set up database replication                                         |
| `remove_database_replication`        | Remove database replication                                         |
| `restart_failed_forests`             | Restarts failed forests                                             |
| `rollback_incomplete_transaction`    | Rolls back incomplete transactions - required when switching to DR  |
| `execute_setup_scripts`              | Executes bespoke setup scripts                                      |



