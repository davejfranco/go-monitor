package main

import (
	"fmt"
	"os"
	"os/signal"
	"sync"
	"time"

	probing "github.com/prometheus-community/pro-bing"
)

func main() {
	var targets []*Target
	targets = append(targets, NewTarget("www.google.com", ""))
	targets = append(targets, NewTarget("localhost", ""))
	monitor(targets)
}

type health struct {
	consecutiveSuccesses int
	consecutiveFailure   int
	actionRunning        bool
}

type Target struct {
	Host     string
	Iface    string
	Count    int
	Size     int
	TTL      int
	Timeout  time.Duration
	Interval time.Duration
	health   health
	mu       sync.Mutex
}

func NewTarget(host, iface string) *Target {
	return &Target{
		Host:     host,
		Iface:    iface,
		Count:    -1,
		Size:     24,
		TTL:      64,
		Timeout:  time.Second * 100000,
		Interval: time.Second,
	}
}

func monitor(targets []*Target) {
	var wg sync.WaitGroup

	for _, t := range targets {
		wg.Go(func() {
			err := t.Probe()
			if err != nil {
				fmt.Fprintf(os.Stderr, "probe failed for %s: %v\n", t.Host, err)
			}
		})
	}
	wg.Wait()
}

func (t *Target) Probe() error {
	pinger, err := probing.NewPinger(t.Host)
	if err != nil {
		return err
	}

	done := make(chan bool) // to stop ticker
	defer close(done)
	c := make(chan os.Signal, 1) // handle interrupt
	signal.Notify(c, os.Interrupt)

	go func() {
		for range c {
			pinger.Stop()
		}
	}()

	pinger.InterfaceName = t.Iface
	pinger.Count = t.Count
	pinger.Size = t.Size
	pinger.TTL = t.TTL
	pinger.Timeout = t.Timeout
	pinger.Interval = t.Interval

	pinger.OnRecv = func(pkt *probing.Packet) {
		fmt.Printf("%d bytes from %s icmp_seq=%d time=%v ttl=%v\n",
			pkt.Nbytes, pkt.IPAddr, pkt.Seq, pkt.Rtt, pkt.TTL)
	}

	// Check target
	t.healthMonitor(pinger, done, time.Second*5)

	err = pinger.Run()
	if err != nil {
		return err
	}
	return nil
}

func (t *Target) healthMonitor(pinger *probing.Pinger, done chan bool, interval time.Duration) {
	ticker := time.NewTicker(interval)
	go func() {
		for {
			select {
			case <-done:
				ticker.Stop()
				return
			case <-ticker.C:
				t.evaluateHealth(pinger.Statistics())
			}
		}
	}()
}

func (t *Target) evaluateHealth(stats *probing.Statistics) {
	t.mu.Lock()
	defer t.mu.Unlock()

	if stats.PacketLoss >= float64(80) {
		t.health.consecutiveSuccesses = 0
		t.health.consecutiveFailure++

		if t.health.consecutiveFailure >= 3 && !t.health.actionRunning {
			fmt.Println("Run remediation")
			t.health.actionRunning = true
		}
	} else if stats.PacketLoss < float64(20) {
		t.health.consecutiveFailure = 0
		t.health.consecutiveSuccesses++

		if t.health.consecutiveSuccesses >= 5 && t.health.actionRunning {
			fmt.Println("Stop action")
			t.health.actionRunning = false
		}
	}
}

func ping(host string) {
	pinger, err := probing.NewPinger(host)
	if err != nil {
		fmt.Println("Error:", err)
		return
	}

	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)
	go func() {
		for range c {
			pinger.Stop()
		}
	}()

	pinger.OnRecv = func(pkt *probing.Packet) {
		fmt.Printf("%d bytes from %s icmp_seq=%d time=%v ttl=%v\n",
			pkt.Nbytes, pkt.IPAddr, pkt.Seq, pkt.Rtt, pkt.TTL)
	}

	pinger.OnDuplicateRecv = func(pkt *probing.Packet) {
		fmt.Printf("%d bytes from %s icmp_seq=%d time=%v ttl=%v (DUP!)\n",
			pkt.Nbytes, pkt.IPAddr, pkt.Seq, pkt.Rtt, pkt.TTL)
	}

	pinger.OnFinish = func(stats *probing.Statistics) {
		fmt.Printf("\n--- %s ping statistics ---\n", stats.Addr)
		fmt.Printf("%d packets transmitted, %d packets received, %d duplicates, %v%% packet loss\n",
			stats.PacketsSent, stats.PacketsRecv, stats.PacketsRecvDuplicates, stats.PacketLoss)
		fmt.Printf("round-trip min/avg/max/stddev = %v/%v/%v/%v\n",
			stats.MinRtt, stats.AvgRtt, stats.MaxRtt, stats.StdDevRtt)
	}

	fmt.Printf("Ping %s (%s):\n", pinger.Addr(), pinger.IPAddr())
	err = pinger.Run()
	if err != nil {
		fmt.Println("failed to ping target host:", err)
	}
}
