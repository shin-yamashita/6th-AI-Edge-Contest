/*
 * readline.h
 *
 *  Created on: Jul 17, 2021
 *      Author: shin
 */

#ifndef INCLUDE_READLINE_H_
#define INCLUDE_READLINE_H_

void list_history();
char *readline(char *prmpt);
void add_history(char *string);

void add_getchar_hook(void (*hook)(void));

#endif /* INCLUDE_READLINE_H_ */
