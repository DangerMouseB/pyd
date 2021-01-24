module pyd.reboot.common;

version(PydStrict)
    enum AlwaysTry = true;
else
    enum AlwaysTry = false;

enum RebootFullTrace = true;
