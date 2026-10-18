//
// Created by CH on 2023/11/17.
//

#ifndef _EPIL_PORTING_H_
#define _EPIL_PORTING_H_

void* epil_malloc(int size);
int epil_free(void* p);
void epil_port_save(double fit);

#endif 
