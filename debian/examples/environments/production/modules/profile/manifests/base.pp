class profile::base {
  notify { "${title} message":
    message => "doing base class things",
  }
}
