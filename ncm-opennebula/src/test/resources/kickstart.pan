object template kickstart;

include 'vm';

prefix "/system/aii/hooks";
"configure/0" = nlist(
    "image", true,
    "template", true,
);

"install/0" = nlist(
    "vm", true,
    "onhold", true,
);

"remove/0" = nlist(
    "vm", true,
    "image", true,
    "template", true,
);
