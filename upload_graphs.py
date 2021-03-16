from http.server import BaseHTTPRequestHandler, HTTPServer
import global_variables

hostName = "localhost"
serverPort= 8080

#file = open("./total_interactions.html")
graph1 =  open(global_variables.htmlTotalBar)
graph2 =  open(global_variables.htmlTotalPie)
totalsBar = graph1.read()
totalsPie = graph2.read()

class MyServer(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content.type", "html")
        self.end_headers()
        self.wfile.write(bytes(totalsBar, "utf-8"))
        self.wfile.write(bytes(totalsPie, "utf-8"))

if __name__== "__main__":
    webServer = HTTPServer((hostName, serverPort), MyServer)
    print("Server started http://%s:%s" % (hostName,serverPort))

    try:
        webServer.serve_forever()

    except KeyboardInterrupt:
        pass

    webServer.server_close()
    print("Server stopped.")