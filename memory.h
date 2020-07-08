// TODO
extern void set     (uint addr, char v);
extern char get     (uint addr);
extern void export  (void * from, uint to, size_t len);
extern void import  (uint from, void * to, size_t len);
extern void move    (uint from, uint to, size_t len);
extern void ememset (uint to, size_t len, char v);
extern uint estrchr (uint addr, char v);
