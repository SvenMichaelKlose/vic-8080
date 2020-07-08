// TODO
extern void set     (uint addr, char v);
extern char get     (uint addr);
extern void move_to  (uint to, void * from, size_t len);
extern void move_from  (void * to, uint from, size_t len);
extern void move    (uint from, uint to, size_t len);
extern void ememset (uint to, size_t len, char v);
extern uint estrchr (uint addr, char v);
extern uint estrlen (uint addr);
extern void estrcat (uint to, char *);
