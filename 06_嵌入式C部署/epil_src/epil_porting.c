#include <stdlib.h>

#include "epil_porting.h"

void* epil_malloc(int size) {
    if (size <= 0) {
        return NULL;
    }

    return malloc((size_t)size);
}

int epil_free(void* p) {
    free(p);
    return 0;
}

void epil_port_save(double fit) {
    (void)fit;
}
