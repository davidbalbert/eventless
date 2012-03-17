#include <string.h>

#include <netinet/in.h>
#include <arpa/inet.h>

#include <ruby.h>

static VALUE mEventless;
static VALUE mSockaddr;

VALUE
rb_eventless_pack_sockaddr_in(VALUE self, VALUE port, VALUE host, VALUE sa_family)
{
        VALUE packed_str;

        if (NUM2INT(sa_family) == AF_INET) {
                struct sockaddr_in a;
                memset(&a, 0, sizeof(a));

                a.sin_family = AF_INET;
                a.sin_port = htons(NUM2INT(port));
                inet_pton(AF_INET, RSTRING_PTR(host), &a.sin_addr);
                packed_str = rb_str_new((char *)&a, sizeof(struct sockaddr_in));
        } else if (NUM2INT(sa_family) == AF_INET6) {
                struct sockaddr_in6 a;
                memset(&a, 0, sizeof(a));

                a.sin6_family = AF_INET6;
                a.sin6_port = htons(NUM2INT(port));
                inet_pton(AF_INET6, RSTRING_PTR(host), &a.sin6_addr);
                packed_str = rb_str_new((char *)&a, sizeof(struct sockaddr_in6));
        } else {
                rb_raise(rb_eArgError, "sa_family must be either Socket::AF_INET or Socket::AF_INET6");
        }

        return packed_str;
}

void
Init_sockaddr(void)
{
        mEventless = rb_define_module("Eventless");
        mSockaddr = rb_define_module_under(mEventless, "Sockaddr");

        rb_define_singleton_method(mSockaddr, "pack_sockaddr_in", rb_eventless_pack_sockaddr_in, 3);
}
