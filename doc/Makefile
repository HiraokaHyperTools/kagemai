ERUBY=erb -Ke

.SUFFIXES: .html .rhtml

.rhtml.html: footer
	${ERUBY} $< | nkf -de > $@

TARGET = guide.html install.html index.html migrate.html page-template.html lifecycle.html

all: $(TARGET)

$(TARGET) : footer

clean:
	rm $(TARGET)
