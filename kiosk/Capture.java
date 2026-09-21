import java.awt.*;
import java.io.File;
import javax.imageio.ImageIO;

/** Build-time graphical smoke-test helper; not included in the appliance. */
public class Capture {
    public static void main(String[] args) throws Exception {
        Rectangle screen = new Rectangle(Toolkit.getDefaultToolkit().getScreenSize());
        ImageIO.write(new Robot().createScreenCapture(screen), "png", new File(args[0]));
    }
}
