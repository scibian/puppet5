This is a small example environment using the "roles and profiles" pattern, as
described in http://www.craigdunn.org/2012/05/239/

With this design pattern, a server has one role, which consists of multiple
profiles.

File layout:

 * manifests/*.pp - manifests applied to all nodes.  Mainly used for
   classification and setting defaults.

 * modules/role/manifests/*.pp - one file per role, which are "business
   requirement" for a server.  Example: "role::loadbalancer",
   "role::mailing_list_server".

 * modules/profile/manifests/*.pp - one file per profile, which are "technical
   implementation stacks".  Examples: "profile::base", "profile::apache_httpd",
   "profile::varnish"

 * modules/* - other modules included by the profiles, specific to this
   environment.

In addition, modules may be loaded from the basemodulepath 
(puppet agent --configprint basemodulepath)
