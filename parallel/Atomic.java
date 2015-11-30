public class Main {

	public static volatile boolean running = true;
	public static int cnt = 0;

public static void main(String[] args) throws InterruptedException {
	System.out.println("start");
	Thread t = new Thread( () -> { System.out.println("Ich bin ein Thread"); while (running) { cnt++; }; } );
	t.start();
	Thread.sleep(1000);
	running = false;
	t.join();
	System.out.println("ende");
	System.out.println("ausgefuhrt: " + cnt);
	System.err.println(cnt);
}

}
