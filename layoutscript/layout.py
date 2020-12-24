import xml.dom.minidom
import os.path
from os import path

# create the overlay
overlay = bytearray(1024)

#        <bounds left="0" top="0" right="224" bottom="260" />
#        <color red="1" green="1" blue="1" />

width = 256
height = 224

vertical = ['invad2ct','invaders','escmars','galactic','yosakdon']
flip = ['invaders','escmars','galactic','yosakdon']


def drawRect(left,top,right,bottom,red,green,blue):
    print('inside drawrect','left',left,'top',top,'right',right,'bottom',bottom,'rgb:',red,green,blue)
    # sanity check
    if (left<0): 
      left=0
    if (top<0): 
      top=0
    if (right>width): 
      right=width
    if (bottom>height): 
      bottom=height

    for y in range(top,bottom-1):
      for x in range(left,right-1):
        offset = (y*width+x) >> 3
        #print('offset',offset,'y',y,'x',x)
        color_offset = ((offset>> 8 << 5) | (offset& 0x1f))
        #uint8_t y = offset >> 5;
        #uint8_t x = offset << 3;
        val = 0
        if (red>0.49):
           val = val | 0x01
        if (green>0.48):
           val = val | 0x04
        if (blue>0.48):
           val = val | 0x02
        overlay[color_offset+128]=val
        #print(x,y,offset,color_offset,val)
 
with open('names') as fin:
    for line in fin:
      line = line.strip()
      if (len(line)):
         #print(line)
         layout='layout/'+line+'.lay';
         if (path.exists(layout)):
           print('*'+layout)
           overlay = bytearray(1024)
           doc = xml.dom.minidom.parse(layout);
           #print(doc.nodeName)
           #print(doc.firstChild.tagName)
           #print(doc)
           elements = doc.getElementsByTagName("element")
           for element in elements:
              if (element.getAttribute("name")=="overlay"):
                 #print(element.getAttribute("name"))
                 rects = element.getElementsByTagName("rect")
                 for rect in rects:
                    bounds = rect.getElementsByTagName("bounds")
                    color = rect.getElementsByTagName("color")
                    if (color and not bounds):
                      red=color[0].getAttribute("red")
                      green=color[0].getAttribute("green") 
                      blue=color[0].getAttribute("blue")
                      print('<full screen>',red,green,blue)
                      drawRect(0,0,int(width),int(height),float(red),float(green),float(blue))
                    if (bounds and color):
                      left=bounds[0].getAttribute("left")
                      top=bounds[0].getAttribute("top")
                      right=bounds[0].getAttribute("right")
                      bottom=bounds[0].getAttribute("bottom")
                      red=color[0].getAttribute("red")
                      green=color[0].getAttribute("green") 
                      blue=color[0].getAttribute("blue")
                      print(left,top,right,bottom,red,green,blue)
                      if (line in vertical):	
                        if (line in flip):	
                          # def drawRect(left,top,right,bottom,red,green,blue):
                          print('in flip')
                          drawRect(round(width-float(bottom)),round(float(left)),round(width-float(top)),round(float(right)),float(red),float(green),float(blue))
                        else:
                          drawRect(round(float(top)),round(float(left)),round(float(bottom)),round(float(right)),float(red),float(green),float(blue))
                      else:
                         drawRect(round(float(left)),round(float(top)),round(float(right)),round(float(bottom)),float(red),float(green),float(blue))
                      #<rect>
                      #        <bounds left="0" top="0" right="224" bottom="260" />
                      #        <color red="1" green="1" blue="1" />
                      #</rect>
           print('writing file')
           newFile = open("col_"+line+".bin", "wb")
           # write to file
           newFile.write(overlay)
           newFile.close()
           newFile = open("col_"+line+".txt", "w")
           # write to file
           newFile.write(' '.join(format(x, '02x') for x in overlay))
           newFile.close()

         else:
           #print('N'+layout)
           pass

