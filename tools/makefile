
CFLAGS = -lm -lgif

OBJS = gifr bytesc bitsc room spriteas resp blit vis palc wani

all : $(OBJS)

$(OBJS) : % : %.c
	$(CC) $(CFLAGS) -o $@ $< -O2

clean :
	rm -f $(OBJS)
